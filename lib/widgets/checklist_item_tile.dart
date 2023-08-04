import 'package:flutter/material.dart';
import 'package:simplistic_checklist/constants/colours.dart';
import '../model/checklist_item.dart';

class ChecklistItemTile extends StatefulWidget {
  final ChecklistItem checklistItem;
  final onChecklistItemTap;
  final onChecklistItemDelete;
  const ChecklistItemTile(
      {super.key,
      required this.checklistItem,
      required this.onChecklistItemTap,
      required this.onChecklistItemDelete});

  @override
  State<ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends State<ChecklistItemTile> {
  Future<bool?> _showDeleteConfirmationDialog(String key) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          surfaceTintColor: Colors.transparent,
          actionsPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this item?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Close the dialog
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                // remove item from checklist
                widget.onChecklistItemDelete(widget.checklistItem);
                Navigator.of(context).pop(true); // Close the dialog
              },
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.checklistItem.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.red,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (DismissDirection direction) async {
        return await _showDeleteConfirmationDialog(widget.checklistItem.id);
      },
      onDismissed: (direction) {
        // This will be triggered after the confirmation
        // dialog has been dismissed with "Delete" action.
        // We do not need to do anything here.
      },
      child: ListTile(
        onTap: () {
          widget.onChecklistItemTap(widget.checklistItem);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        tileColor: Colors.white,
        splashColor: Colors.grey.shade100,
        leading: Icon(
            widget.checklistItem.isCompleted
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            color: widget.checklistItem.isCompleted
                ? tdGrey
                : Colors.teal.shade300),
        title: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            widget.checklistItem.checklistText!,
            softWrap: true,
            style: TextStyle(
                letterSpacing: 0.1,
                color: widget.checklistItem.isCompleted ? tdGrey : tdBlack,
                fontSize: 14,
                decoration: widget.checklistItem.isCompleted
                    ? TextDecoration.lineThrough
                    : null),
          ),
        ),
      ),
    );
  }
}
