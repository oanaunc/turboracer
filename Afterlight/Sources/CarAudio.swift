import AVFoundation

@MainActor final class CarAudio {
    private var motor: AVAudioPlayer?
    private var spark: AVAudioPlayer?
    init(enabled:Bool) {
        guard enabled else { return }
        if let url=Bundle.main.url(forResource:"engine",withExtension:"wav") { motor=try? AVAudioPlayer(contentsOf:url); motor?.enableRate=true; motor?.numberOfLoops = -1; motor?.volume=0.14; motor?.prepareToPlay() }
        if let url=Bundle.main.url(forResource:"spark",withExtension:"wav") { spark=try? AVAudioPlayer(contentsOf:url); spark?.volume=0.4; spark?.prepareToPlay() }
    }
    func update(speed:Double,boost:Bool) { if motor?.isPlaying == false { motor?.play() }; motor?.rate=Float(min(2,max(0.6,0.65+speed/60+(boost ? 0.2 : 0)))) }
    func collect() { spark?.currentTime=0; spark?.play() }
    func stop() { motor?.pause() }
}
