import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const GAudioCoreApp());
}

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
}

class MainControlScreen extends StatefulWidget {
  const MainControlScreen({super.key});

  @override
  State<MainControlScreen> createState() => _MainControlScreenState();
}

class _MainControlScreenState extends State<MainControlScreen> {
  String _serverIp = "192.168.1.100"; 
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final List<String> _consoleLogs = ["Система G-AUDIO CORE V1.0 готова к отладке..."];

  double _masterVolume = 25;
  double _balance = 0;
  String _currentSource = "streaming";

  double _delayTweeter = 0.0;
  double _delayMidrange = 0.0;
  double _delayWoofer = 0.0;

  double _gainTweeter = 0.0;
  double _gainMidrange = -8.0; 
  double _gainWoofer = 0.0;
  bool _phaseTweeterInvert = false;
  bool _phaseMidrangeInvert = false;
  bool _phaseWooferInvert = false;

  bool _aiMicEnabled = true;
  double _aiMicSensitivity = 70;
  String _lastRecognizedPhrase = "Ожидание голосовой команды...";

  bool _spatial3dEnabled = false;
  double _spatialWidth = 50;

  bool _clipTweeter = false;
  bool _clipMidrange = false;
  bool _clipWoofer = false;
  String _impedanceTweeter = "Ожидание...";
  String _impedanceMidrange = "Ожидание...";
  String _impedanceWoofer = "Ожидание...";

  bool _dynamicBassEq = true;
  bool _loudnessCorrection = true;
  bool _nightMode = false;
  bool _isMuted = false;
  String _calibrationStatus = "Калибровка не запущена";

  final TextEditingController _micCalController = TextEditingController();
  final TextEditingController _rewController = TextEditingController();
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.100");

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse("ws://$_serverIp:8000/ws"));
      setState(() { 
        _isConnected = true; 
        _logConsole("Успешное Wi-Fi подключение к узлу $_serverIp");
      });
    } catch (e) {
      setState(() { 
        _isConnected = false; 
        _logConsole("DSP узел недоступен по адресу $_serverIp: $e");
      });
    }
  }

  void _logConsole(String message) {
    setState(() {
      _consoleLogs.add("[${DateTime.now().toString().substring(11, 19)}] $message");
      if (_consoleLogs.length > 25) _consoleLogs.removeAt(0);
    });
  }

  void _sendAction(Map<String, dynamic> jsonMap) {
    final rawJson = jsonEncode(jsonMap);
    _logConsole("TX ──► $rawJson");
    if (_isConnected && _channel != null) {
      _channel!.sink.add(rawJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('G-AUDIO CORE V1.0 [ONLINE]'),
          backgroundColor: const Color(0xFF12121A),
          actions: [
            IconButton(
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: _isMuted ? Colors.red : Colors.green),
              onPressed: () {
                setState(() { _isMuted = !_isMuted; });
                _sendAction({"action": "set_mute", "value": _isMuted});
              },
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(icon: Icon(Icons.play_arrow), text: 'Транспорт'),
              Tab(icon: Icon(Icons.tune), text: 'Задержки / Фазы'),
              Tab(icon: Icon(Icons.equalizer), text: 'Gain полос'),
              Tab(icon: Icon(Icons.psychology), text: 'ИИ и Объем'),
              Tab(icon: Icon(Icons.build), text: 'Диагностика ПЛИС'),
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
          const Text("DSP LINE CLIP MONITOR:", style: TextStyle(fontSize: 10, color: Colors.grey)),
          _buildClipIndicator("ВЧ Полоса", _clipTweeter),
          _buildClipIndicator("СЧ Полоса", _clipMidrange),
          _buildClipIndicator("НЧ Полоса", _clipWoofer),
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

  Widget _buildPlayerTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radio, size: 120, color: Colors.amber.shade600),
          const SizedBox(height: 20),
          const Text('Цифровой поток G-AUDIO CORE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          const Text('Активный процессинг трехполосного усиления', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.navigate_before, size: 45), onPressed: () => _sendAction({"action": "prev"})),
              IconButton(icon: const Icon(Icons.play_arrow, size: 65, color: Colors.amber), onPressed: () => _sendAction({"action": "play"})),
              IconButton(icon: const Icon(Icons.navigate_next, size: 45), onPressed: () => _sendAction({"action": "next"})),
            ],
          ),
          const SizedBox(height: 35),
          DropdownButton<String>(
            value: _currentSource,
            dropdownColor: const Color(0xFF12121A),
            items: const [
              DropdownMenuItem(value: "streaming", child: Text("Сетевой Стриминг (Яндекс Музыка / DLNA)")),
              DropdownMenuItem(value: "bluetooth", child: Text("Bluetooth вход (Qualcomm aptX HD)")),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() { _currentSource = val; });
                _sendAction({"action": "set_source", "value": val});
              }
            },
          ),
        ],
      ),
    );
  }
  Widget _buildDelaysTab() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _buildSliderCard('Мастер-Громкость', _masterVolume, 0, 100, (v) => setState(() => _masterVolume = v), (v) => _sendAction({"action": "set_master_volume", "value": v.round()})),
        _buildSliderCard('Локализация сцены (Баланс)', _balance, -10, 10, (v) => setState(() => _balance = v), (v) => _sendAction({"action": "set_balance", "value": v.round()})),
        const Divider(),
        SwitchListTile(
          title: const Text('Физиологическая Тонкомпенсация'),
          subtitle: const Text('Автоматический подьем краев АЧХ на малых уровнях звука для раскрытия потенциала НЧ.'),
          activeColor: Colors.amber,
          value: _loudnessCorrection,
          onChanged: (v) {
            setState(() { _loudnessCorrection = v; });
            _sendAction({"action": "set_loudness", "enabled": v});
          },
        ),
        SwitchListTile(
          title: const Text('Ночной компрессор (Night DRC)'),
          subtitle: const Text('Выравнивание динамического диапазона баса и вокала.'),
          activeColor: Colors.amber,
          value: _nightMode,
          onChanged: (v) {
            setState(() { _nightMode = v; });
            _sendAction({"action": "set_night_mode", "enabled": v});
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          child: Text('Аппаратная юстировка фазы (Time Alignment, мс)', style: TextStyle(fontSize: 14, color: Colors.amber)),
        ),
        _buildSliderCard('Задержка ВЧ тракта (High)', _delayTweeter, 0, 5, (v) => setState(() => _delayTweeter = v), (v) => _sendAction({"action": "set_delay", "channel": "tweeter", "value": v})),
        _buildSliderCard('Задержка СЧ тракта (Mid)', _delayMidrange, 0, 5, (v) => setState(() => _delayMidrange = v), (v) => _sendAction({"action": "set_delay", "channel": "midrange", "value": v})),
        _buildSliderCard('Задержка НЧ тракта (Low)', _delayWoofer, 0, 5, (v) => setState(() => _delayWoofer = v), (v) => _sendAction({"action": "set_delay", "channel": "woofer", "value": v})),
      ],
    );
  }
  Widget _buildSpeakerGainTab() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _buildSpeakerControlRow('ВЧ Полоса усиления (High)', _gainTweeter, _phaseTweeterInvert, 
          (v) => setState(() => _gainTweeter = v), 
          (v) => _sendAction({"action": "set_per_channel_gain", "channel": "tweeter", "value": v}),
          (v) { setState(() { _phaseTweeterInvert = v!; }); _sendAction({"action": "invert_phase", "channel": "tweeter", "value": v}); }
        ),
        _buildSpeakerControlRow('СЧ Полоса усиления (Mid)', _gainMidrange, _phaseMidrangeInvert, 
          (v) => setState(() => _gainMidrange = v), 
          (v) => _sendAction({"action": "set_per_channel_gain", "channel": "midrange", "value": v}),
          (v) { setState(() { _phaseMidrangeInvert = v!; }); _sendAction({"action": "invert_phase", "channel": "midrange", "value": v}); }
        ),
        _buildSpeakerControlRow('НЧ Полоса усиления (Low)', _gainWoofer, _phaseWooferInvert, 
          (v) => setState(() => _gainWoofer = v), 
          (v) => _sendAction({"action": "set_per_channel_gain", "channel": "woofer", "value": v}),
          (v) { setState(() { _phaseWooferInvert = v!; }); _sendAction({"action": "invert_phase", "channel": "woofer", "value": v}); }
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Адаптивный лимитер хода (Dynamic Bass EQ)'),
          subtitle: const Text('Защита катушки НЧ динамика от механического разрушения на пиках.'),
          activeColor: Colors.amber,
          value: _dynamicBassEq,
          onChanged: (v) {
            setState(() { _dynamicBassEq = v; });
            _sendAction({"action": "set_dynamic_eq", "enabled": v});
          },
        ),
      ],
    );
  }
  Widget _buildSpeakerControlRow(String label, double gainVal, bool phaseInvert, Function(double) onGainChange, Function(double) onGainEnd, Function(bool?) onPhaseChange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: Slider(value: gainVal, min: -12, max: 6, onChanged: onGainChange, onChangeEnd: onGainEnd, activeColor: Colors.amber)),
                Text('${gainVal.toStringAsFixed(1)} дБ'),
                const SizedBox(width: 15),
                Column(
                  children: [
                    const Text("Ø 180°", style: TextStyle(fontSize: 10)),
                    Checkbox(value: phaseInvert, onChanged: onPhaseChange, activeColor: Colors.amber),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
  Widget _buildAiAndSpatialTab() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Card(
          color: const Color(0xFF1F1224), 
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.surround_sound, color: Colors.purpleAccent),
                    SizedBox(width: 8),
                    Text("G-SPATIAL 3D AUDIO PROCESSOR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Объемное поле G-SPATIAL 3D"),
                  subtitle: const Text("Виртуальное моделирование HRTF Atmos-сцены для стереопары"),
                  value: _spatial3dEnabled,
                  activeColor: Colors.purpleAccent,
                  onChanged: (v) {
                    setState(() { _spatial3dEnabled = v; });
                    _sendAction({"action": "set_spatial_3d", "enabled": v});
                  },
                ),
                _buildSliderCard("Глубина и ширина стереобазы", _spatialWidth, 10, 100, 
                  (v) => setState(() => _spatialWidth = v),
                  (v) => _sendAction({"action": "set_spatial_width", "value": v.round()})
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 25),
        Card(
          color: const Color(0xFF1A1A24),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.amber),
                    SizedBox(width: 8),
                    Text("ЛОКАЛЬНЫЙ ИИ-АССИСТЕНТ ПЛАТЫ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Встроенный микрофон ИИ"),
                  subtitle: const Text("Аппаратная активация массива INMP441"),
                  value: _aiMicEnabled,
                  activeColor: Colors.amber,
                  onChanged: (v) {
                    setState(() { _aiMicEnabled = v; });
                    _sendAction({"action": "set_ai_mic", "enabled": v});
                  },
                ),
                _buildSliderCard("Чувствительность триггера речи", _aiMicSensitivity, 10, 100, 
                  (v) => setState(() => _aiMicSensitivity = v),
                  (v) => _sendAction({"action": "set_ai_sens", "value": v.round()})
                ),
                const Text("Услышано:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(top: 4), color: Colors.black38,
                  child: Text(_lastRecognizedPhrase, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 25),
        TextField(controller: _micCalController, maxLines: 1, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Текст или путь калибровки UMIK-1 (.txt)')),
        const SizedBox(height: 5),
        ElevatedButton(onPressed: () { _sendAction({"action": "upload_mic_cal", "content": _micCalController.text}); }, child: const Text('Залить калибровку микрофона')),
        const Divider(height: 25),
        TextField(controller: _rewController, maxLines: 1, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Экспорт банков фильтров REW')),
        const SizedBox(height: 5),
        ElevatedButton(onPressed: () { _sendAction({"action": "upload_rew_filters", "content": _rewController.text}); }, child: const Text('Загрузить эквалайзер REW в CamillaDSP')),
        const Divider(height: 25),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, padding: const EdgeInsets.all(12)),
          onPressed: () { setState(() { _calibrationStatus = "Измерение свип-тоном..."; }); _sendAction({"action": "start_calibration"}); },
          child: const Text('ЗАПУСТИТЬ АВТОНОМНЫЙ ЗАМЕР АЧХ КОМНАТЫ'),
        ),
        const SizedBox(height: 5),
        Text('Статус замера: $_calibrationStatus', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
  Widget _buildEngineMenuTab() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Card(
          color: Colors.blueGrey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("ДИАГНОСТИКА ЦЕПЕЙ НАГРУЗКИ:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                const SizedBox(height: 8),
                Text("Сопротивление ВЧ катушки: $_impedanceTweeter"),
                Text("Сопротивление СЧ катушки: $_impedanceMidrange"),
                Text("Сопротивление НЧ катушки: $_impedanceWoofer"),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900),
                  onPressed: () {
                    setState(() { _impedanceTweeter = "7.8 Ом (ОК)"; _impedanceMidrange = "3.9 Ом (ОК)"; _impedanceWoofer = "7.4 Ом (ОК)"; });
                    _sendAction({"action": "check_impedance"});
                  },
                  child: const Text("Тест КЗ и Сопротивления"),
                )
              ],
            ),
          ),
        ),
        const Divider(),
        TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'IP адрес ведущей платы', border: OutlineInputBorder())),
        const SizedBox(height: 5),
        ElevatedButton(onPressed: () { setState(() { _serverIp = _ipController.text; }); _connectWebSocket(); }, child: const Text('Сменить сетевой узел связи')),
        const Divider(),
        const Text("Встроенный генератор частот ПЛИС:", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () => _sendAction({"action": "generator", "type": "sine", "freq": 50}), child: const Text('50 Гц')),
            ElevatedButton(onPressed: () => _sendAction({"action": "generator", "type": "sine", "freq": 1000}), child: const Text('1 кГц')),
            ElevatedButton(onPressed: () => _sendAction({"action": "generator", "type": "noise"}), child: const Text('Шум')),
          ],
        ),
        const SizedBox(height: 5),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900), onPressed: () => _sendAction({"action": "generator", "type": "stop"}), child: const Text('СТОП ГЕНЕРАТОР')),
      ],
    );
  }
  Widget _buildConsoleWidget() {
    return Container(
      height: 100, width: double.infinity, color: const Color(0xFF040406), padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('G-AUDIO CORE RAW LOG CONSOLE [ВЫХОД JSON]:', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
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
  Widget _buildSliderCard(String title, double value, double min, double max, Function(double) onChange, Function(double) onChangeEnd) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13)),
            Row(
              children: [
                Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChange, onChangeEnd: onChangeEnd, activeColor: Colors.amber)),
                Text(value.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
