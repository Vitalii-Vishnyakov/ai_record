import UIKit
import AVFoundation

class RecordViewController: UIViewController {
    private let llama = QwenLlamaService()
    
    // MARK: - UI
    
    private let startRecordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Начать аудиозапись", for: .normal)
        return button
    }()
    
    private let stopRecordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Закончить аудиозапись", for: .normal)
        return button
    }()
    
    private let sumirizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Суммаризовать", for: .normal)
        return button
    }()
    
    private let makeTranscriptionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Сделать транскрипцию", for: .normal)
        return button
    }()
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Запустить проигрывание", for: .normal)
        return button
    }()
    
    private let stopPlayButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Остановить проигрывание", for: .normal)
        return button
    }()
    
    private let testTranscribeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Запустить тестовую расшифровку", for: .normal)
        return button
    }()
    
    private let urlScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let urlLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = "Ссылка на запись появится здесь"
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private let activity: UIActivityIndicatorView = {
        let activity = UIActivityIndicatorView(style: .medium)
        activity.hidesWhenStopped = true
        return activity
    }()
    
    // MARK: - Audio
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var lastRecordingURL: URL?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupActions()
        requestMicrophonePermission()
        
        Task(priority: .userInitiated) {
            try await llama.loadModel()
        }
        
        AppState.shared.observer = { [weak self] newState in
            switch newState {
            case .modelLoading:
                self?.urlLabel.text = "Прогреваем модель..."
                self?.activity.startAnimating()
                self?.activity.color = .blue
            case .transcribing:
                self?.urlLabel.text = "Расшифровываем..."
                self?.activity.startAnimating()
                self?.activity.color = .cyan
            case .recording:
                self?.urlLabel.text = "Записываем..."
                self?.activity.startAnimating()
                self?.activity.color = .red
            case .summirizing:
                self?.urlLabel.text = "Суммаризируем..."
                self?.activity.startAnimating()
                self?.activity.color = .green
            case .none:
                self?.activity.stopAnimating()
                self?.activity.color = .white
            }
        }
    }
    
    func showSummText(text: String){
        urlLabel.text = text
    }
    
    func sendUrl(url: URL) {
    }
    
    func runLocalTest() {}
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Стек кнопок
        let stack = UIStackView(arrangedSubviews: [
            startRecordButton,
            stopRecordButton,
            playButton,
            stopPlayButton,
            sumirizeButton,
            makeTranscriptionButton,
            testTranscribeButton,
            activity
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.distribution = .fillEqually
        
        view.addSubview(stack)
        view.addSubview(urlScrollView)
        urlScrollView.addSubview(urlLabel)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        urlScrollView.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            urlScrollView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            urlScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            urlScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            urlScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Контент в scrollView
            urlLabel.topAnchor.constraint(equalTo: urlScrollView.contentLayoutGuide.topAnchor),
            urlLabel.leadingAnchor.constraint(equalTo: urlScrollView.contentLayoutGuide.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: urlScrollView.contentLayoutGuide.trailingAnchor),
            urlLabel.bottomAnchor.constraint(equalTo: urlScrollView.contentLayoutGuide.bottomAnchor),
            
            // Ограничиваем ширину, чтобы работали переносы строк + скролл при очень длинной ссылке
            urlLabel.widthAnchor.constraint(equalTo: urlScrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    private func setupActions() {
        startRecordButton.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
        stopRecordButton.addTarget(self, action: #selector(stopRecording), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(startPlaying), for: .touchUpInside)
        stopPlayButton.addTarget(self, action: #selector(stopPlaying), for: .touchUpInside)
        testTranscribeButton.addTarget(self, action: #selector(startTestTranscription), for: .touchUpInside)
        sumirizeButton.addTarget(self, action: #selector(sumirizeButtonTap), for: .touchUpInside)
        makeTranscriptionButton.addTarget(self, action: #selector(makeTranscriptionButtonTap), for: .touchUpInside)
    }
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() {
        audioSession.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.showAlert(title: "Нет доступа к микрофону",
                                   message: "Разрешите доступ к микрофону в настройках, чтобы записывать аудио.")
                }
            }
        }
    }
    
    // MARK: - Recording
    
    private func prepareRecorder() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = documents.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.prepareToRecord()
        
        lastRecordingURL = fileURL
        updateURLLabel(with: fileURL)
    }
    
    @objc private func startRecording() {
        do {
            AppState.shared.state = .recording
            try prepareRecorder()
            audioRecorder?.record()
        } catch {
            showAlert(title: "Ошибка записи", message: error.localizedDescription)
        }
    }
    
    @objc private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        AppState.shared.state = .none
        if let lastRecordingURL {
            sendUrl(url: lastRecordingURL)
        }
    }
    
    // MARK: - Playback
    
    @objc private func startPlaying() {
        guard let url = lastRecordingURL else {
            showAlert(title: "Нет записи", message: "Сначала сделайте аудиозапись.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            showAlert(title: "Ошибка проигрывания", message: error.localizedDescription)
        }
    }
    
    @objc private func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    @objc private func makeTranscriptionButtonTap() {
        if let lastRecordingURL {
            sendUrl(url: lastRecordingURL)
        }
    }
    
    @objc private func sumirizeButtonTap() {
        if let lasText = self.urlLabel.text {
            Task(priority: .userInitiated) { [lasText] in
                let text = try await llama.summarize(text: lasText)
                await MainActor.run {
                    showSummText(text: text)
                }
            }
        }
    }
    
    let prmop = "Я очень рано потерял родителей. Осталась только фотография отца — бывшего офицера царской армии. Мать почти совсем не помню. Родных братьев и сестер у меня не было. Сначала меня воспитывал детдом, потом я вступил в партию, а после пришел в ЦИХСПД. Тяжело жить одному как перст, хочется быть в составе большой семьи.  С первой женой мы разошлись, когда в стране начались разговоры о негативе партийной идеологии. Я тогда из партии вышел, а супруга посчитала это личным предательством. Так и расстались.  Со второй женой мы познакомились в ЦИХСПД и прожили вместе до последнего вздоха моей ненаглядной. Сейчас я продолжаю активную жизнь в ЦИХСПД, читаю там лекции для взрослых, участвую в разных видах помощи нуждающимся: то ремонт в квартире, то организовать лечение, да много всяких дел. И там мы — как одна большая семья. Каждый раз ждем встреч, обнимаемся как родные люди, мы в курсе дел друг друга, всегда поддерживаем каждого из нас.  Думаю, деньги в жизни не главное. Гораздо важнее не давать себе распускаться, поддерживать режим дня, рано вставать и рано ложиться, работать и жить по совести, дорожить своей семьей — и будет радость и спокойствие в жизни."
    // MARK: - Test Transcription
    
    @objc private func startTestTranscription() {
        runLocalTest()
    }
    
    // MARK: - Helpers
    
    private func updateURLLabel(with url: URL) {
        urlLabel.text = "Путь к последней записи:\n\(url.path)"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

