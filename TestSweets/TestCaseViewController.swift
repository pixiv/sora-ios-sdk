import UIKit
import Sora

class TestCaseViewController: UITableViewController, TestCaseControllable {

    enum State {
        case connecting
        case connected
        case disconnected
    }
    
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var configurationLabel: UILabel!
    @IBOutlet weak var keepConnectionSwitch: UISwitch!
    @IBOutlet weak var connectLabel: UILabel!
    @IBOutlet weak var connectionTimeLabel: UILabel!
    @IBOutlet weak var connectionTimeValueLabel: UILabel!
    @IBOutlet weak var numberOfStreamsLabel: UILabel!
    @IBOutlet weak var numberOfStreamsValueLabel: UILabel!
    
    @IBOutlet weak var configurationCell: UITableViewCell!
    @IBOutlet weak var connectCell: UITableViewCell!
    @IBOutlet weak var numberOfStreamsCell: UITableViewCell!
    @IBOutlet weak var duplicateCell: UITableViewCell!

    weak var mainViewController: MainViewController!
    weak var videoViewListViewController: VideoViewListViewController?
    
    weak var testCaseController: TestCaseController! {
        didSet {
            configurationViewController?.configuration = testCase.configuration
        }
    }
    
    var testCase: TestCase! {
        get { return testCaseController.testCase }
    }
    
    var configurationViewController: ConfigurationViewController!
    var configuration: Configuration?
    
    var keepsConnection: Bool {
        get {
            return keepConnectionSwitch.isOn
        }
    }
    
    var numberOfStreams: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.numberOfStreamsValueLabel.text = String(self.numberOfStreams)
            }
        }
    }
    
    var state: State = .disconnected {
        didSet {
            DispatchQueue.main.async {
                switch self.state {
                case .connecting:
                    self.connectLabel.text = "Connecting..."
                    
                case .connected:
                    self.connectLabel.text = "Disconnect"
                    self.numberOfStreamsCell.isUserInteractionEnabled = true
                    self.numberOfStreamsLabel.setTextOn(true)
                    self.numberOfStreams =
                        self.testCaseController.mediaChannel!.streams.count
                    self.startConnectionTimer()
                    self.configurationViewController.lock()
                    
                case .disconnected:
                    self.testCaseController.mediaChannel = nil
                    self.connectLabel.text = "Connect"
                    self.numberOfStreamsCell.isUserInteractionEnabled = false
                    self.numberOfStreamsLabel.setTextOn(false)
                    self.numberOfStreams = 0
                    self.stopConnectionTimer()
                    self.configurationViewController.unlock()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        state = .disconnected
        configurationViewController = ConfigurationViewController()
        configurationViewController.navigationItem.title = "Configuration"
        configurationViewController.configuration = testCase.configuration
        numberOfStreams = 0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        testCase.configuration = configurationViewController.configuration
        TestSuiteManager.shared.save()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? VideoViewListViewController {
            vc.testCaseController = testCaseController
            videoViewListViewController = vc
        }
    }
    
    // MARK: Table View Delegate
    
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let cell = tableView.cellForRow(at: indexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            if cell == configurationCell {
                configurationViewController.configuration = testCase.configuration
                present(configurationViewController, animated: true)
            } else if cell == connectCell {
                connectOrDisconnect()
            } else if cell == duplicateCell {
                duplicateTestCase()
                navigationController?.popViewController(animated: true)
            }
        }
    }
    
    // MARK: アクション
    
    func reloadTestCase() {
        let _ = view
        titleTextField.text = testCase.title
    }
    
    var stopwatch: Utilities.Stopwatch?
    
    func startConnectionTimer() {
        connectionTimeLabel.setTextOn(true)
        connectionTimeValueLabel.setTextOn(true)
        stopwatch = Utilities.Stopwatch { time in
            DispatchQueue.main.async {
                self.connectionTimeValueLabel.text = time
            }
        }
        stopwatch?.run()
    }
    
    func stopConnectionTimer() {
        stopwatch?.stop()
        connectionTimeLabel.setTextOn(false)
        connectionTimeValueLabel.setTextOn(false)
        connectionTimeValueLabel.text = "--:--:--"
    }
    
    func disconnect() {
        testCaseController.disconnect(error: nil)
        state = .disconnected
    }
    
    func connectOrDisconnect() {
        switch state {
        case .connecting, .connected:
            disconnect()
            
        case .disconnected:
            configurationViewController.validate { config, error in
                if let error = error {
                    self.state = .disconnected
                    showAlert(title: "Invalid Configuration", message: error)
                    return
                }
                
                if config!.role != .subscriber && CameraVideoCapturer.shared.isRunning {
                    CameraVideoCapturer.shared.stop()
                }
                
                self.state = .connecting
                self.configuration = config
                Sora.shared.connect(configuration: config!) { chan, error in
                    if let error = error {
                        self.state = .disconnected
                        self.showAlert(title: "Connection Failure",
                                       message: error.localizedDescription)
                        return
                    } else if chan == nil {
                        self.state = .disconnected
                        self.showAlert(title: "Connection Failure",
                                       message: "MediaChannel is none")
                        return
                    }
                    
                    self.testCaseController.mediaChannel = chan
                    guard !chan!.streams.isEmpty else {
                        self.state = .disconnected
                        chan!.disconnect(error: nil)
                        self.showAlert(title: "Connection Failure",
                                       message: "Media streams are none")
                        return
                    }
                    
                    chan!.handlers.onConnectHandler = { error in
                        self.mainViewController.update()
                    }

                    chan!.handlers.onDisconnectHandler = { error in
                        self.mainViewController.update()
                    }
                    
                    chan!.handlers.onFailureHandler = { error in
                        self.state = .disconnected
                        self.showAlert(title: "Connection Failure",
                                       message: error.localizedDescription)
                        self.mainViewController.update()
                    }
                    
                    chan!.handlers.onAddStreamHandler = { stream in
                        self.numberOfStreams += 1
                        self.videoViewListViewController?.reloadData()
                    }
                    
                    chan!.handlers.onRemoveStreamHandler = { stream in
                        self.numberOfStreams -= 1
                        self.videoViewListViewController?.reloadData()
                    }
                    
                    self.state = .connected
                }
            }
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .cancel))
        present(alert, animated: true)
    }
    
    func duplicateTestCase() {
        let newTestCase = TestCase(id: Utilities.randomString(),
                                   title: testCase.title,
                                   configuration: testCase.configuration)
        TestSuiteManager.shared.add(testCase: newTestCase)
    }
    
    @IBAction func titleTextFieldEditingDidEndOnExit(_ sender: AnyObject) {
        TestSuiteManager.shared.save { _ in
            testCase.title = titleTextField.text ?? ""
        }
    }
    
    @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            titleTextFieldEditingDidEndOnExit(sender)
            view.endEditing(true)
        }
    }

}
