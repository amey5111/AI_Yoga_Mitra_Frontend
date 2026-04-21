import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/health_info.dart';
import '../utils/language_helper.dart';
import 'goals_screen.dart';

class HealthInfoScreen extends StatefulWidget {
  const HealthInfoScreen({super.key});

  @override
  State<HealthInfoScreen> createState() => _HealthInfoScreenState();
}

class _HealthInfoScreenState extends State<HealthInfoScreen> {
  double height = 60.0;
  double weight = 60.0;

  final heightController = TextEditingController();
  final weightController = TextEditingController();

  List<String> selectedConditions = [];
  final otherController = TextEditingController();

  /// 🔹 INTERNAL ENGLISH VALUES (used for backend)
  final List<String> conditions = [
    "Diabetes",
    "Thyroid",
    "High BP",
    "PCOS",
    "Arthritis",
    "Asthma",
    "Leg Injury",
  ];

  /// 🔹 DISPLAY TRANSLATIONS
  String getConditionDisplay(String condition) {
    switch (condition) {
      case "Diabetes":
        return LanguageHelper.t("Diabetes", "मधुमेह", "मधुमेह");
      case "Thyroid":
        return LanguageHelper.t("Thyroid", "थायरॉईड", "थायरॉइड");
      case "High BP":
        return LanguageHelper.t("High BP", "उच्च रक्तदाब", "उच्च रक्तचाप");
      case "PCOS":
        return LanguageHelper.t("PCOS", "पीसीओएस", "पीसीओएस");
      case "Arthritis":
        return LanguageHelper.t("Arthritis", "सांधेदुखी", "गठिया");
      case "Asthma":
        return LanguageHelper.t("Asthma", "दमा", "दमा");
      case "Leg Injury":
        return LanguageHelper.t("Leg Injury", "पायाला  दुखापत", "पैर की चोट");
      default:
        return condition;
    }
  }

  @override
  void initState() {
    super.initState();
    heightController.text = height.toString();
    weightController.text = weight.toString();
  }

  void updateHeight(double value) {
    setState(() {
      height = value;
      heightController.text = value.toStringAsFixed(1);
    });
  }

  void updateWeight(double value) {
    setState(() {
      weight = value;
      weightController.text = value.toStringAsFixed(1);
    });
  }

  void next() {
    final provider = Provider.of<UserProvider>(context, listen: false);

    List<String> finalConditions = [...selectedConditions];

    if (otherController.text.isNotEmpty) {
      finalConditions.addAll(
        otherController.text.split(",").map((e) => e.trim()),
      );
    }

    provider.setHealthInfo(
      HealthInfo(
        height: height,
        weight: weight,
        medicalConditions: finalConditions, // ✅ Still English
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    LanguageHelper.loadLanguage();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageHelper.t("Health Info", "आरोग्य माहिती", "स्वास्थ्य जानकारी"),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// HEIGHT
            Text(
              LanguageHelper.t("Height (inches)", "उंची (इंच)", "ऊंचाई (इंच)"),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => updateHeight(height - 0.5),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null) height = val;
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => updateHeight(height + 0.5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// WEIGHT
            Text(LanguageHelper.t("Weight (kg)", "वजन (किलो)", "वजन (किलो)")),
            Row(
              children: [
                IconButton(
                  onPressed: () => updateWeight(weight - 0.5),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null) weight = val;
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => updateWeight(weight + 0.5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// MEDICAL CONDITIONS (Translated UI, English Stored)
            ...conditions.map(
              (c) => CheckboxListTile(
                value: selectedConditions.contains(c),
                title: Text(getConditionDisplay(c)), // ✅ Translated display
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selectedConditions.add(c); // ✅ English stored
                    } else {
                      selectedConditions.remove(c);
                    }
                  });
                },
              ),
            ),

            TextField(
              controller: otherController,
              decoration: InputDecoration(
                labelText: LanguageHelper.t(
                  "Other (comma separated)",
                  "इतर (स्वल्पविरामाने वेगळे करा)",
                  "अन्य (कॉमा से अलग करें)",
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              LanguageHelper.t(
                "*Your health data is securely stored locally on your device.",
                "*आपला आरोग्य डेटा आपल्या डिव्हाइसवर सुरक्षित आहे.",
                "*आपका स्वास्थ्य डेटा आपके डिवाइस पर सुरक्षित है.",
              ),
              style: const TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: next,
              child: Text(LanguageHelper.t("Next", "पुढे", "आगे")),
            ),
          ],
        ),
      ),
    );
  }
}
