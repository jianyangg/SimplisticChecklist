import 'package:flutter/material.dart';
import 'package:simplistic_checklist/constants/colours.dart';
import 'package:simplistic_checklist/widgets/checklist_item_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/checklist_item.dart';

// todo: add functionality to shift the order of the checklist items
// todo: add functionality to edit the checklist items

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> checklists = [];
  Map<String, List<ChecklistItem>> checklistMap = {};
  List<ChecklistItem> currChecklist = [];
  late SharedPreferences prefs;
  final TextEditingController _addChecklistNameController =
      TextEditingController();
  final TextEditingController _addChecklistItemController =
      TextEditingController();
  bool isDefaultChecklist = true;
  String currListName = "main7dL5&gK9q@2mF";

  void _handleChecklistItemTap(ChecklistItem checklistItem) {
    setState(() {
      checklistItem.isCompleted = !checklistItem.isCompleted;
      _sortChecklist();
    });
    // update shared preferences
    List<String> checklistItemsStrings = [];
    List<String> checklistItemsCompletion = [];
    for (final item in currChecklist) {
      checklistItemsStrings.add(item.checklistText.toString());
      checklistItemsCompletion.add(item.isCompleted.toString());
    }
    prefs.setStringList(currListName, checklistItemsStrings);
    prefs.setStringList('${currListName}_completion', checklistItemsCompletion);
  }

  void openDrawer() {
    _scaffoldKey.currentState!.openDrawer();
  }

  void _deleteChecklistItem(ChecklistItem item) {
    setState(() {
      currChecklist.remove(item);
      // update shared preferences
      List<String> checklistItemsStrings = [];
      List<String> checklistItemsCompletion = [];
      for (final item in currChecklist) {
        checklistItemsStrings.add(item.checklistText.toString());
        checklistItemsCompletion.add(item.isCompleted.toString());
      }
      prefs.setStringList(currListName, checklistItemsStrings);
      prefs.setStringList(
          '${currListName}_completion', checklistItemsCompletion);
    });
  }

  void _addChecklistItem(ChecklistItem item) {
    setState(() {
      currChecklist.add(item);
      // update shared preferences
      List<String> checklistItemsStrings = [];
      List<String> checklistItemsCompletion = [];

      for (final item in currChecklist) {
        checklistItemsStrings.add(item.checklistText.toString());
      }
      prefs.setStringList(currListName, checklistItemsStrings);
      prefs.setStringList(
          '${currListName}_completion', checklistItemsCompletion);
    });
  }

  void _sortChecklist() {
    // Sort the currChecklist list based on the isCompleted property.
    // Completed items will be moved to the bottom of the list.
    // If both items have the same isCompleted value, then sort by id.
    currChecklist.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) {
        return 1;
      } else if (!a.isCompleted && b.isCompleted) {
        return -1;
      } else {
        // If both items have the same isCompleted value, sort by id.
        return int.parse(a.id).compareTo(int.parse(b.id));
      }
    });
    // update shared preferences
    List<String> checklistItemsStrings = [];
    List<String> checklistItemsCompletion = [];
    for (final item in currChecklist) {
      checklistItemsStrings.add(item.checklistText.toString());
      checklistItemsCompletion.add(item.isCompleted.toString());
    }
    prefs.setStringList(currListName, checklistItemsStrings);
    prefs.setStringList('${currListName}_completion', checklistItemsCompletion);
  }

  Future<void> loadChecklists() async {
    prefs = await SharedPreferences.getInstance();
    // clear all prefs
    // ther's a bug
    // prefs.clear();
    // Load the checklists from shared preferences
    // made it weird so that it's hard to decode or replicate
    List<String>? checklistsStrings =
        prefs.getStringList('masterChecklist7dL5&gK9q@2mF');
    if (checklistsStrings != null) {
      print(checklistsStrings);
      setState(() {
        checklists = checklistsStrings;
      });
      print("checklists: $checklists");
      if (checklists.isEmpty) {
        setState(() {
          currChecklist.addAll(ChecklistItem.defaultChecklist());
        });
      }
    }
    for (final checklist in checklists) {
      List<String>? checklistItemsStrings = prefs.getStringList(checklist);
      List<String>? checklistItemsCompletion =
          prefs.getStringList('${checklist}_completion');
      print("checklistItemsCompletion: $checklistItemsCompletion");
      print("checklistItemsStrings: $checklistItemsStrings");
      if (checklistItemsStrings != null && checklistItemsCompletion != null) {
        List<ChecklistItem> checklistItems = [];
        checklistItems = ChecklistItem.constructChecklist(
            checklistItemsStrings, checklistItemsCompletion);
        setState(() {
          // print checklistmap for debugging
          print("checklistMap: $checklistMap");
          checklistMap[checklist] = checklistItems;
        });
      }
    }

    // get lastLoadedList from shared preferences
    String? lastLoadedList = prefs.getString('lastLoadedList');
    print("lastLoadedList: $lastLoadedList");
    if (lastLoadedList != null) {
      setState(() {
        currListName = lastLoadedList!;
        currChecklist = lastLoadedList == "main7dL5&gK9q@2mF"
            ? ChecklistItem.defaultChecklist()
            : checklistMap[currListName]!;
        isDefaultChecklist = lastLoadedList == "main7dL5&gK9q@2mF";
      });
    } else {
      lastLoadedList = "main7dL5&gK9q@2mF";
      setState(() {
        currListName = lastLoadedList!;
        currChecklist = checklistMap[currListName]!;
        isDefaultChecklist = true;
      });
      prefs.setString(lastLoadedList, currListName);
    }
  }

  // void _onReorder(int oldIndex, int newIndex) {
  //   setState(() {
  //     if (newIndex == oldIndex) {
  //       return; // Item remains at the same position, no need to reorder
  //     }

  //     if (newIndex > oldIndex) {
  //       newIndex -=
  //           1; // Account for the shifting of the items after removing the old item
  //     }

  //     final ChecklistItem item = currChecklist.removeAt(oldIndex);
  //     final GlobalKey key = _itemKeys.removeAt(oldIndex);
  //     currChecklist.insert(newIndex, item);
  //     _itemKeys.insert(newIndex, key);
  //   });
  // }

  @override
  void initState() {
    super.initState();
    loadChecklists();
    currChecklist.addAll(ChecklistItem.defaultChecklist());
  }

  @override
  void dispose() {
    _addChecklistNameController.dispose();
    super.dispose();
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: tdBackground,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: tdBackground,
        actions: [
          // IconButton(
          //   onPressed: () {
          //     showDialog(
          //       context: context,
          //       builder: (context) {
          //         return AlertDialog(
          //           surfaceTintColor: Colors.transparent,
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(11),
          //           ),
          //           title: const Text(
          //             'About',
          //             style: TextStyle(
          //               fontSize: 20,
          //               fontWeight: FontWeight.bold,
          //             ),
          //           ),
          //           content: const Text(
          //             "This app is made for value investors and is inspired by the checklist on page 73 of Poor Charlie's Almanack.\n\nThere's also the option of creating your own lists to cater to your specific investment philosophy.\n\nThere are many checklists online, but few that's actionable and easy to access. Hence, this app was born to help investors stay rational in their investment process.\n\nIf you like this app, check out our other apps on the App Store:\n\n\t\t- Value Investing Tools (for discounted cash flow analysis, margin of safety, and internal rate of return calculations)",
          //             style: TextStyle(fontSize: 15),
          //           ),
          //           actions: [
          //             TextButton(
          //               onPressed: () {
          //                 Navigator.pop(context);
          //               },
          //               child: const Text(
          //                 'OK',
          //                 style: TextStyle(
          //                   color: Colors.black,
          //                   fontSize: 18,
          //                   fontWeight: FontWeight.bold,
          //                 ),
          //               ),
          //             ),
          //           ],
          //         );
          //       },
          //     );
          //   },
          //   icon: const Icon(Icons.info_outline),
          // ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    surfaceTintColor: Colors.transparent,
                    actionsPadding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    title: const Text("Reset Checklist"),
                    content: const Text(
                        "Are you sure you want to reset the checklist? This action cannot be undone."),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // reset all checklist items
                          setState(() {
                            for (var element in currChecklist) {
                              element.isCompleted = false;
                            }
                            _sortChecklist();
                          });
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text(
                          "Reset",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.refresh_sharp),
          ),
          IconButton(
              onPressed: () {
                // add checklist item
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      title: const Text(
                        'Add item',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: TextField(
                        controller: _addChecklistItemController,
                        autofocus: true,
                        decoration: const InputDecoration(
                            // hintText: 'New item',
                            ),
                        style: const TextStyle(fontSize: 15),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // clear text field
                            _addChecklistItemController.clear();
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black,
                              // fontSize: 18,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // add new checklist
                            setState(() {
                              String newChecklistItem =
                                  _addChecklistItemController.text;
                              if (newChecklistItem.isNotEmpty) {
                                ChecklistItem newItem = ChecklistItem(
                                    id: (currChecklist.length + 1).toString(),
                                    checklistText: newChecklistItem);
                                _addChecklistItem(newItem);
                              }
                            });
                            _addChecklistItemController.clear();
                            _sortChecklist();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              color: Colors.black,
                              // fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.add)),
          IconButton(
            icon: Icon(Icons.delete,
                color: isDefaultChecklist ? Colors.grey : Colors.black),
            onPressed: () {
              if (isDefaultChecklist) {
                // showDialog saying cannot delete Main checklist
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      surfaceTintColor: Colors.transparent,
                      actionsPadding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      title: const Text("Error"),
                      content: const Text(
                          "You cannot delete this tutorial checklist. However, you can reset it."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the dialog
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                      ],
                    );
                  },
                );
              } else {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      surfaceTintColor: Colors.transparent,
                      actionsPadding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      title: const Text("Delete Checklist"),
                      content: const Text(
                          "Are you sure you want to delete this checklist? This action cannot be undone."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the dialog
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // delete checklist
                            setState(() {
                              checklists.remove(currListName);
                              prefs.setStringList(
                                  'masterChecklist7dL5&gK9q@2mF', checklists);
                              prefs.remove(currListName);
                              currChecklist = checklists.isNotEmpty
                                  ? checklistMap[checklists[0]]!
                                  : ChecklistItem.defaultChecklist();
                              isDefaultChecklist =
                                  checklists.isNotEmpty ? false : true;
                              currListName = checklists.isNotEmpty
                                  ? checklists[0]
                                  : "main7dL5&gK9q@2mF";
                              prefs.setString("lastLoadedList", currListName);
                            });
                            Navigator.of(context).pop(); // Close the dialog
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                      ],
                    );
                  },
                );
              }
              // show dialog to confirm intention to delete,
              // then delete from shared preferences
            },
          ),
          const SizedBox(width: 5),
        ],
      ),
      drawer: Drawer(
        surfaceTintColor: Colors.transparent,
        width: MediaQuery.of(context).size.width * 0.6,
        backgroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 110,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white12,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 3,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        "assets/images/icon.png",
                        height: 20,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Lists',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              title: const Text(
                                'Add New List',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: TextField(
                                controller: _addChecklistNameController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter checklist name',
                                ),
                                style: const TextStyle(fontSize: 15),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // clear text field
                                    _addChecklistNameController.clear();
                                  },
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.black,
                                      // fontSize: 18,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    String newChecklistName =
                                        _addChecklistNameController.text;
                                    // if checklist name exists, show error dialog and pop context
                                    // else, add new checklist
                                    if (checklists.contains(newChecklistName)) {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            surfaceTintColor:
                                                Colors.transparent,
                                            actionsPadding:
                                                const EdgeInsets.all(16),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            title: const Text("Error"),
                                            content: const Text(
                                                "Duplicate checklist name. Please try again."),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(); // Close the dialog
                                                },
                                                child: const Text(
                                                  "OK",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                            ],
                                          );
                                        },
                                      );
                                    } else {
                                      // add new checklist
                                      setState(() {
                                        if (newChecklistName.isNotEmpty &&
                                            newChecklistName !=
                                                "main7dL5&gK9q@2mF") {
                                          checklists.add(newChecklistName);
                                          prefs.setStringList(
                                              'masterChecklist7dL5&gK9q@2mF',
                                              checklists);
                                          checklistMap[newChecklistName] = [];
                                          prefs.setStringList(
                                              newChecklistName, []);
                                          prefs.setStringList(
                                              "${newChecklistName}_completion",
                                              []);
                                          currChecklist =
                                              checklistMap[newChecklistName]!;
                                          currListName = newChecklistName;
                                          isDefaultChecklist = false;
                                          prefs.setString(
                                              "lastLoadedList", currListName);
                                        }
                                      });
                                      _addChecklistNameController.clear();
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text(
                                    'OK',
                                    style: TextStyle(
                                      color: Colors.black,
                                      // fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // ListTile(
            //   title: const Text('Main'),
            //   onTap: () {
            //     setState(() {
            //       currChecklist = checklistMap["Main"]!;
            //       isDefaultChecklist = true;
            //       currListName = "Main";
            //     });
            //     Navigator.pop(context);
            //   },
            //   tileColor:
            //       currListName == "Main" ? Colors.grey.shade200 : Colors.white,
            // ),
            // list all items in checklists
            for (final item in checklists)
              ListTile(
                title: Text(item),
                onTap: () {
                  setState(() {
                    print(item);
                    // TODO: load checklist from shared preferences
                    currChecklist = checklistMap[item]!;
                    isDefaultChecklist = false;
                    currListName = item;
                    prefs.setString("lastLoadedList", currListName);
                  });
                  Navigator.pop(context);
                },
                tileColor:
                    currListName == item ? Colors.grey.shade200 : Colors.white,
              ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        // child: ReorderableListView(
        // onReorder: _onReorder,
        child: ListView(
          children: [
            ClipRRect(
              // key: GlobalKey(),
              child: Image.asset(
                "assets/images/quote.png",
                height: 40,
                color: Colors.teal.shade200,
              ),
            ),
            const SizedBox(
              // key: GlobalKey(),
              height: 20,
            ),
            const Text(
              "No wise pilot, no matter how great his talent and experience, fails to use his checklist.",
              textAlign: TextAlign.center,
              style: TextStyle(color: tdBlack, fontSize: 17),
              // key: GlobalKey(),
            ),
            const SizedBox(
              height: 5,
              // key: GlobalKey(),
            ),
            const Row(
              // key: GlobalKey(),
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "- Charlie Munger",
                  textAlign: TextAlign.end,
                  style: TextStyle(color: tdGrey, fontSize: 15),
                ),
                SizedBox(
                  width: 15,
                )
              ],
            ),
            const SizedBox(
              // key: GlobalKey(),
              height: 10,
            ),
            for (int index = 0; index < currChecklist.length; index++)
              Column(
                // key: Key(index.toString()),
                children: [
                  const SizedBox(height: 10),
                  ChecklistItemTile(
                    checklistItem: currChecklist[index],
                    onChecklistItemTap: _handleChecklistItemTap,
                    onChecklistItemDelete: _deleteChecklistItem,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
