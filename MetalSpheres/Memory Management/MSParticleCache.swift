//
//  Created by Maxwell Pirtle on 12/4/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  An abstraction over writing data into caches to be used by the particle renderer
    

import Foundation

final class MSParticleCache {
    
    /// The set of channels the cache manages
    private var channels: [MSParticleCacheChannel] = []
    
    /// All channels for which it is potentially unsafe to read
    /// data from on this thread
    private var unsafeChannels: [MSParticleCacheChannel] = []
    
    /// The number of channels this cache manages
    private(set) var channelsInFlight: Int = 0
    
    // MARK: - Initializer -
    
    init(channels count: Int) {
        channelsInFlight = count
        channels = (0..<count).map { _ in
            MSParticleCacheChannel(cache: self)
        }
    }
    
    // MARK: - API -
    
    /// Returns the current channel that is pending an update.
    /// Only one channel is expected to be in the `.pending` state
    /// at any given time because by the time the GPU schedules
    /// another frame to be rendered, the cache will be moved into
    /// the `.unsafe` state and only one cache is written into at any given time.
    /// Maintaining a reference to this channel and attempting to read its contents
    /// later could result in a data race, which is undefined behavior
    var pendingChannel: MSParticleCacheChannel! { channels.first { $0.isPending } }
    
    /// Prepares the `pendingChannel` particle cache to be written into on another thread
    func dispatchPendingChannel() {
        let pendingChannel = self.pendingChannel.unsafelyUnwrapped
        pendingChannel.state = .unsafe
        unsafeChannels.append(pendingChannel)
        
        // Remove the channel from those that can be accessed
        channels.removeReference(pendingChannel)
    }
    
    /// Either returns the channel that is pending updates or a new channel
    func currentChannel() -> MSParticleCacheChannel! { pendingChannel ?? channels.first { $0.isFree } }
    
    /// Called by the channel when it is safe to read from again
    fileprivate func channelDidFree(_ channel: MSParticleCacheChannel) {
        unsafeChannels.removeReference(channel)
        channels.append(channel)
    }
}

final class MSParticleCacheChannel {
    
    /// The cache the object is managed by
    private(set) unowned var cache: MSParticleCache
    
    /// The state of affairs for the contents of the cache
    fileprivate(set) var state: State = .free
    
    @frozen enum State {
        
        /// The cache is in a state in which it is
        /// safe to read and write particle data
        case free
        
        /// The cache is awaiting to be scheduled
        /// for use by the `synchronizationQueue` of the
        /// particle renderer. At this point, more writes can be
        /// made to the channel
        case pending

        /// The cache is potentially being read from
        /// on another thread. It is unsafe to access the contents
        /// the channel at this point
        case unsafe
        
    }
    
    var isFree: Bool    { state == .free }
    var isPending: Bool { state == .pending }
    var isUnsafe: Bool  { state == .unsafe }
    
    /// The current raw data stored in this cache ready
    /// to be used by the CPU at some point in the future
    private(set) var cachedParticleUpdate: (removing: Set<MSParticleNode>, adding: Set<MSParticleNode>) = ([], [])
    
    /// The expected difference in particles in the universe
    /// accroding to the data in the cache
    var particleChange: Int { cachedParticleUpdate.adding.count - cachedParticleUpdate.removing.count }
    
    // MARK: - Initializer -
    
    init(cache: MSParticleCache) { self.cache = cache }
    
    // MARK: - API -
    
    /// Safely clears the cache on the main thread from an auxiliary
    /// thread after the CPU writes its cache data into the GPU
    func safelyClearCache() {
        DispatchQueue.main.async { [unowned self] in
            unsafelyClearCache()
        }
    }

    func unsafelyClearCache() {
        cachedParticleUpdate = ([], [])
        state = .free
        
        // Move the channel back into the set of channels available
        cache.channelDidFree(self)
    }
    
    func fillCache(_ data: (removing: Set<MSParticleNode>, adding: Set<MSParticleNode>)) {
        cachedParticleUpdate = (data.adding, data.removing)
        state = .pending
    }
    
    func add(_ particle: MSParticleNode) {
        cachedParticleUpdate.adding.insert(particle)
        state = .pending
    }
    
    func remove(_ particle: MSParticleNode) {
        cachedParticleUpdate.removing.insert(particle)
        state = .pending
    }
}
