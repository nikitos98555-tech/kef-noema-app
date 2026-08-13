import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const GAudioCoreApp());

class GAudioCoreApp extends StatelessWidget {
  const GAudioCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G-AUDIO CORE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
      ),
      home: const MainControlScreen(),
    );
  }

class _MainControlScreenState extends State<MainControlScreen> {
  // Переменная с адресом сервера (исправлена опечатка с : на ;)
  String serverIn = "192.168.1.100";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control Screen')),
      body: Center(
        // Используем переменную serverIn через знак \$
        child: Text('Сервер: \$serverIn'),
      ),
    );
  }
}
class _MainControlScreenState extends State<MainControlScreen> {
  String _serverIp = "192.168.1.100";
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  final List<String> _consoleLogs = ["Панель G-AUDIO CORE V1.0 готова"];

  // Транспорт
  String? _currentTrackTitle;
  String? _currentArtist;
  String _currentSource = "streaming";

  // Задержки и фазы
  double _delayTweeter = 0.0;
  double _delayMidrange = 0.0;
  double _delayWoofer = 0.0;

  bool _phaseTweeterInvert = false;
  bool _phaseMidrangeInvert = false;
  bool _phaseWooferInvert = false;

  // Усиление и Headroom
  double _gainTweeter = 0.0;
  double _gainMidrange = -8.0;
  double _gainWoofer = 0.0;

  double _headroomTweeter = 6.0;
  double _headroomMidrange = 6.0;
  double _headroomWoofer = 6.0;

  // ИИ и объём
  bool _aiMicEnabled = true;
  double _aiMicSensitivity = 70;
  String _lastRecognizedPhrase = "Ожидание команды...";

  bool _spatial3dEnabled = false;
  double _spatialWidth = 50;

  // Диагностика
  String _impedanceTweeter = "Ожидание...";
  String _impedanceMidrange = "Ожидание...";
  String _impedanceWoofer = "Ожидание...";
  bool _impedanceOkTweeter = false;
  bool _impedanceOkMidrange = false;
  bool _impedanceOkWoofer = false;

  bool _clipTweeter = false;
  bool _clipMidrange = false;
  bool _clipWoofer = false;

  String _calibrationStatus = "Калибровка не запущена";
  int _calibrationPercent = 0;

  bool _loudnessCorrection = true;
  bool _nightMode = false;
  bool _isMuted = false;

  final TextEditingController _ipController = TextEditingController(text: "192.168.1.100");

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      if (int.tryParse(p) == null) return false;
      final n = int.parse(p);
      return n >= 0 && n <= 255;
    });
  }

  void _connectWebSocket() {
    if (!_isValidIp(_serverIp)) {
      _logConsole("Ошибка: неверный IP");
      return;
    }
    try {
      _channel = WebSocketChannel.connect(Uri.parse("ws://$_serverIp:8000/ws"));
      setState(() {
        _isConnected = true;
        _reconnectTimer = null;
      });
      _logConsole("Подключено к $_serverIp");

      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        _handleServerMessage(data);
      }, onError: (e) {
        setState(() => _isConnected = false);
        _logConsole("Соединение разорвано: $e");
        _startReconnect();
      });
    } catch (e) {
      setState(() => _isConnected = false);
      _logConsole("Не удалось подключиться: $e");
      _startReconnect();
    }
  }

  void _startReconnect() {
    setState(() => _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isConnected) _connectWebSocket();
    }));
  }

  void _handleServerMessage(Map<String, dynamic> data) {
    if (data['event'] == 'connection_status') {
      setState(() => _isConnected = data['connected'] ?? false);
    } else if (data['event'] == 'track_info') {
      setState(() {
        _currentTrackTitle = data['title'];
        _currentArtist = data['artist'];
      });
    } else if (data['event'] == 'headroom') {
      setState(() {
        _headroomTweeter = (data['tweeter'] as num).toDouble();
        _headroomMidrange = (data['midrange'] as num).toDouble();
        _headroomWoofer = (data['woofer'] as num).toDouble();
      });
    } else if (data['event'] == 'impedance') {
      final t = data['tweeter'];
      final m = data['midrange'];
      final w = data['woofer'];
      setState(() {
        _impedanceTweeter = t['value'].toStringAsFixed(1) + ' Ω';
        _impedanceMidrange = m['value'].toStringAsFixed(1) + ' Ω';
        _impedanceWoofer = w['value'].toStringAsFixed(1) + ' Ω';
        _impedanceOkTweeter = t['ok'] ?? false;
        _impedanceOkMidrange = m['ok'] ?? false;
        _impedanceOkWoofer = w['ok'] ?? false;
      });
    } else if (data['event'] == 'clip') {
      setState(() {
        _clipTweeter = data['tweeter'] ?? false;
        _clipMidrange = data['midrange'] ?? false;
        _clipWoofer = data['woofer'] ?? false;
      });
    } else if (data['event'] == 'calibration_status') {
      setState(() {
        _calibrationStatus = data['step'] ?? "Калибровка не запущена";
        _calibrationPercent = data['percent'] ?? 0;
      });
    }
    _logConsole("RX ◀── $message");
  }

  void _sendAction(Map<String, dynamic> jsonMap) {
    final rawJson = jsonEncode(jsonMap);
    _logConsole("TX ──► $rawJson");
    if (_isConnected && _channel != null) {
      _channel!.sink.add(rawJson);
    }
  }

  void _logConsole(String message) {
    setState(() {
      _consoleLogs.add("[${DateTime.now().toString().substring(11, 19)}] $message");
      if (_consoleLogs.length > 25) _consoleLogs.removeAt(0);
    });
  }

  Color _getHeadroomColor(double hr) {
    if (hr < 1.5) return Colors.red;
    if (hr < 3.0) return Colors.orange;
    return Colors.green;
  }

  double get _sampleRate => 48000;
}
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('G-AUDIO CORE'),
          backgroundColor: const Color(0xFF12121A),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? "ONLINE" : "OFFLINE",
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
            IconButton(
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: _isMuted ? Colors.red : Colors.green),
              onPressed: () {
                setState(() => _isMuted = !_isMuted);
                _sendAction({"action": "set_mute", "value": _isMuted});
              },
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(icon: Icon(Icons.play_arrow), text: 'Транспорт'),
              Tab(icon: Icon(Icons.timer), text: 'Задержки / Фазы'),
              Tab(icon: Icon(Icons.equalizer), text: 'Gain полос'),
              Tab(icon: Icon(Icons.psychology), text: 'ИИ и Объём'),
              Tab(icon: Icon(Icons.build), text: 'Диагностика'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildClipMonitorWidget(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlayerTab(),
                  _buildDelaysTab(),
                  _buildSpeakerGainTab(),
                  _buildAiAndSpatialTab(),
                  _buildEngineMenuTab(),
                ],
              ),
            ),
            _buildConsoleWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildClipMonitorWidget() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("CLIP MONITOR:", style: TextStyle(fontSize: 10, color: Colors.grey)),
          _buildClipIndicator("ВЧ", _clipTweeter),
          _buildClipIndicator("СЧ", _clipMidrange),
          _buildClipIndicator("НЧ", _clipWoofer),
        ],
      ),
    );
  }

  Widget _buildClipIndicator(String label, bool isClipping) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isClipping ? Colors.red : Colors.green.shade800)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildConsoleWidget() {
    return Container(
      height: 100,
      width: double.infinity,
      color: const Color(0xFF040406),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOG:', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: _consoleLogs.length,
              itemBuilder: (context, index) => Text(_consoleLogs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTab() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Icon(Icons.radio, size: 120, color: Colors.amber.shade600),
        const SizedBox(height: 20),

        if (_currentTrackTitle != null || _currentArtist != null) ...[
          Text(_currentTrackTitle ?? "Нет трека", style: const Text(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(_currentArtist ?? "", style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 20),
        ] else ...[
          const Text("Ожидание потока...", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
        ],

        const Text('Активный процессинг трёхполосного усиления', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 25),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.navigate_before, size: 45), onPressed: () => _sendAction({"action": "prev"})),
            const SizedBox(width: 20),
            IconButton(icon: Icon(_isMuted ? Icons.pause : Icons.play_arrow, size: 60), onPressed: () => _sendAction({"action": "toggle_play"})),
            const SizedBox(width: 20),
            IconButton(icon: const Icon(Icons.navigate_next, size: 45), onPressed: () => _sendAction({"action": "next"})),
          ],
        ),
        const SizedBox(height: 30),

        const Text('Источник:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _currentSource,
          items: const [
            DropdownMenuItem(value: "streaming", child: Text("Сетевой Стриминг")),
            DropdownMenuItem(value: "bluetooth", child: Text("Bluetooth")),
            DropdownMenuItem(value: "usb", child: Text("USB")),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _currentSource = val);
              _sendAction({"action": "set_source", "value": val});
            }
          },
        ),
      ],
    );
  }
  Widget _buildDelaysTab() {
    final msToSamples = (double ms) => (ms * _sampleRate / 1000).round();

    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Задержки (выравнивание акустики)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildDelayRow("ВЧ (Tweeter)", _delayTweeter, (v) {
            setState(() => _delayTweeter = v);
            _sendAction({"action": "set_delay", "band": "tweeter", "ms": v});
          }),
          _buildDelayRow("СЧ (Midrange)", _delayMidrange, (v) {
            setState(() => _delayMidrange = v);
            _sendAction({"action": "set_delay", "band": "midrange", "ms": v});
          }),
          _buildDelayRow("НЧ (Woofer)", _delayWoofer, (v) {
            setState(() => _delayWoofer = v);
            _sendAction({"action": "set_delay", "band": "woofer", "ms": v});
          }),
          const SizedBox(height: 20),
          const Text('Инверсия фазы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildPhaseToggle("ВЧ", _phaseTweeterInvert, (v) {
            setState(() => _phaseTweeterInvert = v);
            _sendAction({"action": "set_phase", "band": "tweeter", "invert": v});
          }),
          _buildPhaseToggle("СЧ", _phaseMidrangeInvert, (v) {
            setState(() => _phaseMidrangeInvert = v);
            _sendAction({"action": "set_phase", "band": "midrange", "invert": v});
          }),
          _buildPhaseToggle("НЧ", _phaseWooferInvert, (v) {
            setState(() => _phaseWooferInvert = v);
            _sendAction({"action": "set_phase", "band": "woofer", "invert": v});
          }),
        ],
      ),
    );
  }

  Widget _buildDelayRow(String label, double currentValue, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(currentValue.toStringAsFixed(2), style: const TextStyle(fontSize: 14, color: Colors.amber)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: currentValue,
                min: 0,
                max: 20,
                divisions: 200,
                onChanged: (v) => onChanged(v),
                activeColor: Colors.amber,
                inactiveColor: Colors.grey,
              ),
            ),
          ],
        ),
        const Divider(height: 12, indent: 0),
      ],
    );
  }

  Widget _buildPhaseToggle(String label, bool currentValue, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Switch(
          value: currentValue,
          onChanged: (v) => onChanged(v),
          activeColor: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildSpeakerGainTab() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Усиление полос (Gain)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildGainRow("ВЧ (Tweeter)", _gainTweeter, (v) {
            setState(() => _gainTweeter = v);
            _sendAction({"action": "set_gain", "band": "tweeter", "db": v});
          }),
          _buildGainRow("СЧ (Midrange)", _gainMidrange, (v) {
            setState(() => _gainMidrange = v);
            _sendAction({"action": "set_gain", "band": "midrange", "db": v});
          }),
          _buildGainRow("НЧ (Woofer)", _gainWoofer, (v) {
            setState(() => _gainWoofer = v);
            _sendAction({"action": "set_gain", "band": "woofer", "db": v});
          }),
          const SizedBox(height: 20),
          const Text('Headroom (запас до клиппа)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeadroomBox("ВЧ", _headroomTweeter, _getHeadroomColor(_headroomTweeter)),
              const SizedBox(width: 12),
              _buildHeadroomBox("СЧ", _headroomMidrange, _getHeadroomColor(_headroomMidrange)),
              const SizedBox(width: 12),
              _buildHeadroomBox("НЧ", _headroomWoofer, _getHeadroomColor(_headroomWoofer)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.volume_up, size: 18),
              const SizedBox(width: 8),
              Text("Коррекция громкости (Loudness)", style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Switch(
                value: _loudnessCorrection,
                onChanged: (v) {
                  setState(() => _loudnessCorrection = v);
                  _sendAction({"action": "set_loudness_correction", "value": v});
                },
                activeColor: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGainRow(String label, double currentValue, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(currentValue.toStringAsFixed(1), style: const TextStyle(fontSize: 14, color: Colors.amber)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: currentValue,
                min: -24,
                max: 12,
                divisions: 360,
                onChanged: (v) => onChanged(v),
                activeColor: Colors.amber,
                inactiveColor: Colors.grey,
              ),
            ),
          ],
        ),
        const Divider(height: 12, indent: 0),
      ],
    );
  }

  Widget _buildHeadroomBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text("${value.toStringAsFixed(1)} dB", style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAndSpatialTab() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ИИ и пространственный звук', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.mic, size: 20),
              const SizedBox(width: 8),
              Text("Микрофон ИИ‑управления", style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Switch(
                value: _aiMicEnabled,
                onChanged: (v) {
                  setState(() => _aiMicEnabled = v);
                  _sendAction({"action": "set_ai_mic", "enabled": v});
                },
                activeColor: Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text("Чувствительность:", style: TextStyle(fontSize: 13)),
              const Spacer(),
              Text(_aiMicSensitivity.toString(), style: const TextStyle(fontSize: 13, color: Colors.amber)),
            ],
          ),
          Slider(
            value: _aiMicSensitivity,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) {
              setState(() => _aiMicSensitivity = v);
              _sendAction({"action": "set_ai_sensitivity", "value": v});
            },
            activeColor: Colors.amber,
            inactiveColor: Colors.grey,
          ),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.surround_sound, size: 20),
              const SizedBox(width: 8),
              Text("3D‑пространство (Spatial)", style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Switch(
                value: _spatial3dEnabled,
                onChanged: (v) {
                  setState(() => _spatial3dEnabled = v);
                  _sendAction({"action": "set_spatial", "enabled": v});
                },
                activeColor: Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text("Ширина сцены:", style: TextStyle(fontSize: 13)),
              const Spacer(),
              Text(_spatialWidth.toString(), style: const TextStyle(fontSize: 13, color: Colors.amber)),
            ],
          ),
          Slider(
            value: _spatialWidth,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) {
              setState(() => _spatialWidth = v);
              _sendAction({"action": "set_spatial_width", "value": v});
            },
            activeColor: Colors.amber,
            inactiveColor: Colors.grey,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Последняя команда: $_lastRecognizedPhrase", style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.nightlight, size: 20),
              const SizedBox(width: 8),
              Text("Ночной режим", style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Switch(
                value: _nightMode,
                onChanged: (v) {
                  setState(() => _nightMode = v);
                  _sendAction({"action": "set_night_mode", "value": v});
                },
                activeColor: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }  Widget _buildEngineMenuTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Диагностика системы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // Импеданс
          const Text('Импеданс динамиков', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildImpedanceBox("ВЧ", _impedanceTweeter, _impedanceOkTweeter),
              const SizedBox(width: 12),
              _buildImpedanceBox("СЧ", _impedanceMidrange, _impedanceOkMidrange),
              const SizedBox(width: 12),
              _buildImpedanceBox("НЧ", _impedanceWoofer, _impedanceOkWoofer),
            ],
          ),
          const SizedBox(height: 20),

          // Калибровка
          const Text('Калибровка АЧХ/фазы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_calibrationStatus, style: const TextStyle(color: Colors.grey)),
          LinearProgressIndicator(
            value: (_calibrationPercent / 100).clamp(0, 1),
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.calibration),
                label: const Text("Начать калибровку"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: () {
                  setState(() => _calibrationStatus = "Запуск процедуры...");
                  _sendAction({"action": "start_calibration"});
                },
              ),
            ],
          ),
          const SizedBox(height: 25),

          // Сеть и подключение
          const Text('Сеть и подключение', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: "IP адрес сервера DSP",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.wifi),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isConnected ? Colors.green : Colors.blue),
                child: Text(_isConnected ? "Переподключиться" : "Подключиться"),
                onPressed: _connectWebSocket,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpedanceBox(String label, String value, bool ok) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ok ? Colors.green : Colors.red, width: 2),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
              color: ok ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            )),
          ],
        ),
      ),
    );
  }

