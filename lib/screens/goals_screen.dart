import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/goals.dart';
import '../utils/language_helper.dart';
import 'recommendations_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String level = "Beginner";
  int routineDuration = 30;
  final timeController = TextEditingController(text: "30");

  List<String> painAreas = [];
  List<String> goalsList = [];

  /// 🔹 INTERNAL ENGLISH VALUES (Backend Safe)
  final pains = ["Back", "Neck", "Knee", "Shoulder", "Waist", "Wrist"];

  final goalsOptions = [
    "Flexibility",
    "Stress Relief",
    "Strength",
    "Posture Correction",
    "Weight Loss",
  ];

  final levels = ["Beginner", "Intermediate", "Advanced"];

  /// 🔹 LEVEL DISPLAY
  String getLevelDisplay(String level) {
    switch (level) {
      case "Beginner":
        return LanguageHelper.t("Beginner", "प्राथमिक", "शुरुआती");
      case "Intermediate":
        return LanguageHelper.t("Intermediate", "मध्यम", "मध्यम");
      case "Advanced":
        return LanguageHelper.t("Advanced", "प्रगत", "प्रगत");
      default:
        return level;
    }
  }

  /// 🔹 PAIN DISPLAY
  String getPainDisplay(String pain) {
    switch (pain) {
      case "Back":
        return LanguageHelper.t("Back", "पाठ", "पीठ");
      case "Neck":
        return LanguageHelper.t("Neck", "मान", "गर्दन");
      case "Knee":
        return LanguageHelper.t("Knee", "गुडघा", "घुटना");
      case "Shoulder":
        return LanguageHelper.t("Shoulder", "खांदा", "कंधा");
      case "Waist":
        return LanguageHelper.t("Waist", "कंबर", "कमर");
      case "Wrist":
        return LanguageHelper.t("Wrist", "मनगट", "कलाई");
      default:
        return pain;
    }
  }

  /// 🔹 GOALS DISPLAY
  String getGoalDisplay(String goal) {
    switch (goal) {
      case "Flexibility":
        return LanguageHelper.t("Flexibility", "लवचिकता", "लचीलापन");
      case "Stress Relief":
        return LanguageHelper.t(
          "Stress Relief",
          "ताणतणाव कमी करणे",
          "तनाव से राहत",
        );
      case "Strength":
        return LanguageHelper.t("Strength", "शरीरीक शक्ती", "शरीरीक ताकत");
      case "Posture Correction":
        return LanguageHelper.t(
          "Posture Correction",
          "शरीरीक स्थिती सुधारणा",
          "शरीरीक मुद्रा सुधारणा",
        );
      case "Weight Loss":
        return LanguageHelper.t("Weight Loss", "वजन कमी करणे", "वजन घटाना");
      default:
        return goal;
    }
  }

  void finish() {
    Provider.of<UserProvider>(context, listen: false).setGoals(
      Goals(
        routineDuration: routineDuration,
        focusBodyParts: painAreas, // ✅ English stored
        tags: goalsList, // ✅ English stored
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RecommendationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    LanguageHelper.loadLanguage();

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageHelper.t("Goals", "लक्ष्ये", "लक्ष्य")),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 YOGA LEVEL
            DropdownButtonFormField<String>(
              value: level,
              items: levels
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(getLevelDisplay(e)), // Translated display
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => level = v!),
              decoration: InputDecoration(
                labelText: LanguageHelper.t(
                  "Yoga Level",
                  "योग स्तर",
                  "योग स्तर",
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔹 DAILY TIME
            Text(
              LanguageHelper.t(
                "Daily Time (min)",
                "दररोज वेळ (मिनिटे)",
                "दैनिक समय (मिनट)",
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (routineDuration > 1) {
                      setState(() {
                        routineDuration--;
                        timeController.text = routineDuration.toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: TextField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null) routineDuration = val;
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      routineDuration++;
                      timeController.text = routineDuration.toString();
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// 🔹 PAIN AREAS
            Text(
              LanguageHelper.t(
                "Physical Pain Areas",
                "शारीरिक वेदना क्षेत्रे",
                "शारीरिक दर्द क्षेत्र",
              ),
            ),
            ...pains.map(
              (p) => CheckboxListTile(
                value: painAreas.contains(p),
                title: Text(getPainDisplay(p)), // Translated display
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      painAreas.add(p); // English stored
                    } else {
                      painAreas.remove(p);
                    }
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            /// 🔹 GOALS
            Text(
              LanguageHelper.t(
                "Health Goals",
                "आरोग्य लक्ष्ये",
                "स्वास्थ्य लक्ष्य",
              ),
            ),
            ...goalsOptions.map(
              (g) => CheckboxListTile(
                value: goalsList.contains(g),
                title: Text(getGoalDisplay(g)), // Translated display
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      goalsList.add(g); // English stored
                    } else {
                      goalsList.remove(g);
                    }
                  });
                },
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: finish,
              child: Text(
                LanguageHelper.t(
                  "Get Recommendations",
                  "शिफारसी मिळवा",
                  "सिफारिश प्राप्त करें",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
