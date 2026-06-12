import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../models/person_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/smart_assistant_service.dart';

class SmartAssistantDialog extends StatefulWidget {
  final List<Person> persons;
  final List<Wallet> wallets;
  final Function onComplete;

  const SmartAssistantDialog({super.key, required this.persons, required this.wallets, required this.onComplete});

  @override
  State<SmartAssistantDialog> createState() => _SmartAssistantDialogState();
}

class _SmartAssistantDialogState extends State<SmartAssistantDialog> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    // طلب صلاحية الميكروفون
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب إعطاء صلاحية الميكروفون")));
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "ar_SA", // لغة عربية
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
              if (val.finalResult) _isListening = false;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("المساعد الذكي", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "تحدث أو اكتب العملية...", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _listen,
            child: CircleAvatar(
              radius: 35,
              backgroundColor: _isListening ? Colors.red : Colors.blueGrey,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 10),
          Text(_isListening ? "جاري الاستماع..." : "اضغط وتحدث"),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: () {
            final result = SmartAssistantService.parse(_controller.text, widget.persons, widget.wallets);
            _confirmSave(result);
          },
          child: const Text("حفظ العملية"),
        ),
      ],
    );
  }

  void _confirmSave(SmartParsedData data) {
    if (!data.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ذكر الاسم والمبلغ بوضوح")));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد العملية"),
        content: Text("إضافة ${data.type} لـ ${data.person!.name}\nبمبلغ ${data.amount} ${data.currency ?? 'SAR'}\nمن ${data.wallet?.name ?? 'بدون خزنة'}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تعديل")),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper().addTransaction(Transaction(
                personId: data.person!.id!,
                walletId: data.wallet?.id,
                type: data.type,
                amount: data.amount!,
                description: data.description,
                date: DateTime.now().toIso8601String(),
                currency: data.currency ?? 'SAR',
              ));
              widget.onComplete();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
  }
}