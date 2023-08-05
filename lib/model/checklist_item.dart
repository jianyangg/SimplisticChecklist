class ChecklistItem {
  String id;
  String? checklistText;
  bool isCompleted;

  // default constructor
  ChecklistItem({
    required this.id,
    required this.checklistText,
    this.isCompleted = false,
  });

  static List<ChecklistItem> defaultChecklist() {
    return [
      ChecklistItem(
          id: "1",
          checklistText:
              "Welcome to Simplistic Checklist! Tap on the checkbox to mark an item as completed."),
      ChecklistItem(
          id: "2",
          checklistText:
              "Tap on the trash icon to delete the list. However, you cannot do this for the main list."),
      ChecklistItem(
          id: "3",
          checklistText:
              "Swipe from the right to delete an item from the list. Try it on this item!"),
      ChecklistItem(
          id: "4",
          checklistText:
              "Tap on the add button to add a new item to the list."),
      ChecklistItem(
          id: "5",
          checklistText: "Tap on the refresh button to reset completed items."),
      ChecklistItem(
          id: "6",
          checklistText:
              "Tap on the menu button on the top left to switch between lists and add new lists."),
      ChecklistItem(
          id: "7",
          checklistText:
              "Completed items will be shown with a strikethrough and moved to the bottom of the list.",
          isCompleted: true),
    ];
  }

  static List<ChecklistItem> constructChecklist(
      List<String> checklist, List<String> checklistCompletion) {
    List<ChecklistItem> checklistItems = [];
    for (int i = 0; i < checklist.length; i++) {
      checklistItems.add(ChecklistItem(
          id: i.toString(),
          checklistText: checklist[i],
          isCompleted: checklistCompletion[i] == "true"));
    }
    return checklistItems;
  }
}
