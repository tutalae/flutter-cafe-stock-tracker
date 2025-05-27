import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:convert';
// import 'dart:io'; // Keep this commented out for web or if using embedded JSON string


// --- Data Model ---
class Record {
  String date;
  String shift;
  String roastType;
  String beanName;
  double morningIn;
  double addOnMorning;
  double addOnAfternoon;
  double eveningOut;
  double morningStock;
  double eveningStock;
  int throwAway;
  int test;
  int event;
  int employeeShot;
  String notes;

  Record({
    required this.date,
    required this.shift,
    required this.roastType,
    this.beanName = '',
    this.morningIn = 0.0,
    this.addOnMorning = 0.0,
    this.addOnAfternoon = 0.0,
    this.eveningOut = 0.0,
    this.morningStock = 0.0,
    this.eveningStock = 0.0,
    this.throwAway = 0,
    this.test = 0,
    this.event = 0,
    this.employeeShot = 0,
    this.notes = '',
  });

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      date: map['Date']?.toString() ?? '',
      shift: map['Shift']?.toString() ?? '',
      roastType: map['Roast Type']?.toString() ?? '',
      beanName: map['Bean Name (if SO)']?.toString() ?? '',
      morningIn: double.tryParse(map['Morning In (g)']?.toString() ?? '0') ?? 0.0,
      addOnMorning: double.tryParse(map['Add On Morning (g)']?.toString() ?? '0') ?? 0.0,
      addOnAfternoon: double.tryParse(map['Add On Afternoon (g)']?.toString() ?? '0') ?? 0.0,
      eveningOut: double.tryParse(map['Evening Out (g)']?.toString() ?? '0') ?? 0.0,
      morningStock: double.tryParse(map['Morning Stock (g)']?.toString() ?? '0') ?? 0.0,
      eveningStock: double.tryParse(map['Evening Stock (g)']?.toString() ?? '0') ?? 0.0,
      throwAway: int.tryParse(map['Throw Away (Shot)']?.toString() ?? '0') ?? 0,
      test: int.tryParse(map['Test (Shot)']?.toString() ?? '0') ?? 0,
      event: int.tryParse(map['Event (Shot)']?.toString() ?? '0') ?? 0,
      employeeShot: int.tryParse(map['Employee (Shot)']?.toString() ?? '0') ?? 0,
      notes: map['Notes/Comments']?.toString() ?? '',
    );
  }
}

// --- Google Sheets Configuration ---
const List<String> expectedHeaders = [
  'Date', 'Shift', 'Roast Type', 'Bean Name (if SO)', 'Morning In (g)',
  'Add On Morning (g)', 'Add On Afternoon (g)', 'Evening Out (g)',
  'Morning Stock (g)', 'Evening Stock (g)', 'Throw Away (Shot)',
  'Test (Shot)', 'Event (Shot)', 'Employee (Shot)', 'Notes/Comments'
];

// --- GoogleSheetService Class ---
class GoogleSheetService {
  sheets.SheetsApi? _sheetsApi;
  String? _spreadsheetId;

  final String _serviceAccountJson = r'''
  {
  ------------------------------------------------
  }
  ''';

  final String googleSheetName = 'Daily Checklist';
  final String worksheetName = 'Sheet5';

  Future<bool> initializeSheet() async {
    try {
      final jsonCredentials = _serviceAccountJson;
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(jsonCredentials);
      final client = await auth.clientViaServiceAccount(
        accountCredentials,
        [sheets.SheetsApi.spreadsheetsScope],
      );
      _sheetsApi = sheets.SheetsApi(client);
      _spreadsheetId = '1wlQHhw_vdMKA38hu_ydhnIFAVSCQuZV5Dh79eOrq9Vk'; // Your actual Sheet ID

      if (_spreadsheetId == null || _spreadsheetId!.isEmpty) {
        debugPrint("Error: Spreadsheet ID is not set. Please update _spreadsheetId in GoogleSheetService.");
        return false;
      }

      final currentSheetValuesResponse = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A1:${String.fromCharCode(65 + expectedHeaders.length - 1)}1',
      );
      final List<List<dynamic>>? currentFirstRow = currentSheetValuesResponse.values;

      bool headersMatch = false;
      if (currentFirstRow != null && currentFirstRow.isNotEmpty) {
        if (currentFirstRow[0].length == expectedHeaders.length) {
          headersMatch = true;
          for (int i = 0; i < expectedHeaders.length; i++) {
            if (currentFirstRow[0][i]?.toString() != expectedHeaders[i]) {
              headersMatch = false;
              break;
            }
          }
        }
      }

      if (!headersMatch) {
        debugPrint("Worksheet is empty or headers are missing/incorrect. Adding expected headers...");
        await _sheetsApi!.spreadsheets.values.append(
          sheets.ValueRange(values: [expectedHeaders]),
          _spreadsheetId!,
          worksheetName,
          valueInputOption: 'RAW',
        );
        debugPrint("Headers added to Google Sheet.");
      } else {
        debugPrint("Worksheet headers are already present.");
      }

      debugPrint("Successfully connected to Google Sheet.");
      return true;
    } catch (e) {
      debugPrint("Error connecting to Google Sheet: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllRecordsWithIndex() async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      debugPrint("Google Sheets API not initialized.");
      return [];
    }
    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A:O',
      );
      final List<List<dynamic>> allValues = response.values ?? [];

      if (allValues.isEmpty || allValues.length < 2) {
        return [];
      }

      final headers = allValues[0].map((e) => e.toString()).toList();
      final dataRows = allValues.sublist(1);

      final List<Map<String, dynamic>> recordsWithIndex = [];
      for (int i = 0; i < dataRows.length; i++) {
        final rowValues = dataRows[i];
        final Map<String, dynamic> record = {};
        for (int colIdx = 0; colIdx < headers.length; colIdx++) {
          if (colIdx < rowValues.length) {
            record[headers[colIdx]] = rowValues[colIdx];
          } else {
            record[headers[colIdx]] = '';
          }
        }

        record['Morning In (g)'] = double.tryParse(record['Morning In (g)']?.toString() ?? '0') ?? 0.0;
        record['Add On Morning (g)'] = double.tryParse(record['Add On Morning (g)']?.toString() ?? '0') ?? 0.0;
        record['Add On Afternoon (g)'] = double.tryParse(record['Add On Afternoon (g)']?.toString() ?? '0') ?? 0.0;
        record['Evening Out (g)'] = double.tryParse(record['Evening Out (g)']?.toString() ?? '0') ?? 0.0;
        record['Morning Stock (g)'] = double.tryParse(record['Morning Stock (g)']?.toString() ?? '0') ?? 0.0;
        record['Evening Stock (g)'] = double.tryParse(record['Evening Stock (g)']?.toString() ?? '0') ?? 0.0;
        record['Throw Away (Shot)'] = int.tryParse(record['Throw Away (Shot)']?.toString() ?? '0') ?? 0;
        record['Test (Shot)'] = int.tryParse(record['Test (Shot)']?.toString() ?? '0') ?? 0;
        record['Event (Shot)'] = int.tryParse(record['Event (Shot)']?.toString() ?? '0') ?? 0;
        record['Employee (Shot)'] = int.tryParse(record['Employee (Shot)']?.toString() ?? '0') ?? 0;

        record['__rowIndex'] = i + 2;
        recordsWithIndex.add(record);
      }
      return recordsWithIndex;
    } catch (e) {
      debugPrint("Error fetching records from Google Sheet: $e");
      return [];
    }
  }

  Future<bool> appendRecord(Record record) async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      debugPrint("Google Sheets API not initialized.");
      return false;
    }
    try {
      final List<dynamic> rowData = [
        record.date,
        record.shift,
        record.roastType,
        record.beanName,
        record.morningIn,
        record.addOnMorning,
        record.addOnAfternoon,
        record.eveningOut,
        record.morningStock,
        record.eveningStock,
        record.throwAway,
        record.test,
        record.event,
        record.employeeShot,
        record.notes,
      ];

      await _sheetsApi!.spreadsheets.values.append(
        sheets.ValueRange(values: [rowData]),
        _spreadsheetId!,
        worksheetName,
        valueInputOption: 'RAW',
      );
      debugPrint("Record successfully appended to Google Sheet.");
      return true;
    } catch (e) {
      debugPrint("Error appending record to Google Sheet: $e");
      return false;
    }
  }

  Future<bool> updateExistingRecord(Record record, int rowIndex) async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      debugPrint("Google Sheets API not initialized.");
      return false;
    }
    try {
      final List<dynamic> rowData = [
        record.date,
        record.shift,
        record.roastType,
        record.beanName,
        record.morningIn,
        record.addOnMorning,
        record.addOnAfternoon,
        record.eveningOut,
        record.morningStock,
        record.eveningStock,
        record.throwAway,
        record.test,
        record.event,
        record.employeeShot,
        record.notes,
      ];

      final String range = '$worksheetName!A$rowIndex:${String.fromCharCode(65 + expectedHeaders.length - 1)}$rowIndex';

      await _sheetsApi!.spreadsheets.values.update(
        sheets.ValueRange(values: [rowData]),
        _spreadsheetId!,
        range,
        valueInputOption: 'RAW',
      );
      debugPrint("Record at row $rowIndex successfully updated in Google Sheet.");
      return true;
    } catch (e) {
      debugPrint("Error updating record at row $rowIndex in Google Sheet: $e");
      return false;
    }
  }
}

// --- Utility Functions ---

String formatQuantityDisplay(dynamic value, {String unit = 'g', String roastType = ''}) {
  if (value == null) return 'N/A'; // Handle explicit nulls

  // For shot counts, always return as integer string
  if (unit == 'shot') {
    final int? parsedValue = int.tryParse(value.toString());
    return parsedValue == null || parsedValue == 0 ? '0' : "$parsedValue";
  }

  final double? parsedValue = double.tryParse(value.toString());
  if (parsedValue == null) return value.toString(); // Fallback if not a number

  // For Other Inventory, show 0 instead of N/A if value is 0
  if (roastType == 'Other Inventory') {
    if (parsedValue == 0) return '0';
    return parsedValue == parsedValue.toInt() ? "${parsedValue.toInt()}" : parsedValue.toStringAsFixed(parsedValue.truncateToDouble() == parsedValue ? 0 : 2);
  }

  // For coffee grams
  if (parsedValue == 0) return 'N/A'; // For grams, N/A if 0
  return parsedValue == parsedValue.toInt() ? "${parsedValue.toInt()}g" : "${parsedValue.toStringAsFixed(parsedValue.truncateToDouble() == parsedValue ? 0 : 2)}g";
}


String adjustDate(String currentDateStr, int days) {
  try {
    final currentDate = DateTime.parse(currentDateStr);
    final newDate = currentDate.add(Duration(days: days));
    return DateFormat('yyyy-MM-dd').format(newDate);
  } catch (e) {
    debugPrint("Error adjusting date: $e");
    return currentDateStr;
  }
}

// --- Data Processing Functions (Dashboard and History) ---

Future<List<Record>> getDashboardData(GoogleSheetService sheetService) async {
  final allRecordsWithIndex = await sheetService.getAllRecordsWithIndex();
  final allRecords = allRecordsWithIndex.map((map) => Record.fromMap(map)).toList();

  // Use a Map to ensure only the latest record for each unique (roastType, beanName) is kept
  final Map<String, Record> latestStock = {};

  for (var item in allRecords) {
    // Normalize beanName for uniqueness (trim and lowercase)
    final String normalizedBeanName = item.beanName.trim().toLowerCase();
    final String itemKey = (item.roastType == 'Single Origin' || item.roastType == 'Other Inventory')
        ? '${item.roastType}-$normalizedBeanName'
        : item.roastType;

    final currentDate = DateTime.tryParse(item.date) ?? DateTime(1, 1, 1);

    if (!latestStock.containsKey(itemKey)) {
      latestStock[itemKey] = item;
    } else {
      final existingItem = latestStock[itemKey]!;
      final existingDate = DateTime.tryParse(existingItem.date) ?? DateTime(1, 1, 1);

      // Prioritize by date (newer date is always preferred)
      if (currentDate.isAfter(existingDate)) {
        latestStock[itemKey] = item;
      } else if (currentDate.isAtSameMomentAs(existingDate)) {
        // If same date, prioritize Evening over Morning
        if (item.shift == 'Evening' && existingItem.shift == 'Morning') {
          latestStock[itemKey] = item;
        }
        // If both are Evening, or both Morning for same date, keep the one with more data
        else if (item.shift == existingItem.shift) {
          if (item.eveningStock != 0 && existingItem.eveningStock == 0) {
            latestStock[itemKey] = item;
          } else if (item.morningStock != 0 && existingItem.morningStock == 0 && item.shift == 'Morning') {
            latestStock[itemKey] = item;
          } else if ((item.roastType == 'Single Origin' || item.roastType == 'Other Inventory')
              && item.beanName.isNotEmpty && existingItem.beanName.isEmpty) {
            latestStock[itemKey] = item;
          }
        }
      }
    }
  }

  final displayStock = latestStock.values.toList();
  displayStock.sort((a, b) {
    int roastTypeCompare = a.roastType.compareTo(b.roastType);
    if (roastTypeCompare != 0) return roastTypeCompare;
    return a.beanName.compareTo(b.beanName);
  });

  return displayStock;
}

Future<List<Map<String, dynamic>>> getHistoryData(GoogleSheetService sheetService) async {
  final allRecordsWithIndex = await sheetService.getAllRecordsWithIndex();

  allRecordsWithIndex.sort((a, b) {
    final dateA = DateTime.tryParse(a['Date']?.toString() ?? '') ?? DateTime(1, 1, 1);
    final dateB = DateTime.tryParse(b['Date']?.toString() ?? '') ?? DateTime(1, 1, 1);

    int dateCompare = dateB.compareTo(dateA); // Sort by date descending (newest first)
    if (dateCompare != 0) return dateCompare;

    // For same date, Morning (0) comes before Evening (1)
    int shiftA = (a['Shift']?.toString() == 'Morning') ? 0 : 1;
    int shiftB = (b['Shift']?.toString() == 'Morning') ? 0 : 1;
    return shiftA.compareTo(shiftB);
  });

  return allRecordsWithIndex;
}

Map<String, dynamic> validateAndPrepareRecord({
  required String date,
  required String shift,
  required String roastType,
  String beanName = '',
  String morningInStr = '',
  String addOnMorningStr = '',
  String addOnAfternoonStr = '',
  String eveningOutStr = '',
  String lmMorningStockStr = '',
  String lmEveningStockStr = '',
  String soInStr = '',
  String soOutStr = '',
  String throwAwayStr = '0',
  String testStr = '0',
  String eventStr = '0',
  String employeeShotStr = '0',
  String notes = '',
}) {
  final List<String> validationErrors = [];

  if (date.isEmpty) validationErrors.add("Date");
  if (shift.isEmpty) validationErrors.add("Shift");
  if (roastType.isEmpty) validationErrors.add("Roast Type");

  final bool isSingleOrigin = roastType == 'Single Origin';
  final bool isOtherInventory = roastType == 'Other Inventory'; // NEW check
  final bool isMorningShift = shift == 'Morning';

  // Validate item name if SO or Other Inventory
  if (isSingleOrigin || isOtherInventory) {
    if (beanName.isEmpty) validationErrors.add(isOtherInventory ? "Item Name" : "Bean Name");
  }

  // Validate shot counts only if not Other Inventory
  if (!isOtherInventory) {
    int? employeeShotVal = int.tryParse(employeeShotStr);
    if (employeeShotVal == null) {
      validationErrors.add("Employee (Shot) must be a whole number");
    }
    if (throwAwayStr.isNotEmpty && int.tryParse(throwAwayStr) == null) {
      validationErrors.add("Throw Away must be a whole number");
    }
    if (testStr.isNotEmpty && int.tryParse(testStr) == null) {
      validationErrors.add("Test must be a whole number");
    }
    if (eventStr.isNotEmpty && int.tryParse(eventStr) == null) {
      validationErrors.add("Event must be a whole number");
    }
  }


  // Validate stock/grinder fields based on roast type and shift
  if (isSingleOrigin) {
    if (isMorningShift && soInStr.isEmpty) {
      validationErrors.add("Single Origin Total Stock (IN)");
    } else if (!isMorningShift && soOutStr.isEmpty) {
      validationErrors.add("Single Origin Total Stock (OUT)");
    }
  } else if (isOtherInventory) { // NEW Validation for Other Inventory
    if (isMorningShift && lmMorningStockStr.isEmpty) { // Using LM stock fields for Inventory
      validationErrors.add("Inventory Total Stock (IN)");
    } else if (!isMorningShift && lmEveningStockStr.isEmpty) { // Using LM stock fields for Inventory
      validationErrors.add("Inventory Total Stock (OUT)");
    }
  } else { // Light/Medium Roasts
    if (isMorningShift) {
      if (morningInStr.isEmpty) validationErrors.add("Morning In (g) - Grinder");
      if (lmMorningStockStr.isEmpty) validationErrors.add("Light/Medium Overall Stock (IN)");
    } else {
      if (eveningOutStr.isEmpty) validationErrors.add("Evening Out (g) - Grinder");
      if (lmEveningStockStr.isEmpty) validationErrors.add("Light/Medium Overall Stock (OUT)");
    }
  }


  if (validationErrors.isNotEmpty) {
    return {
      'success': false,
      'message': "Validation Error: Please fill in all required fields: ${validationErrors.join(', ')}.",
    };
  }

  try {
    double morningInVal = 0.0;
    double addOnMorningVal = 0.0;
    double addOnAfternoonVal = 0.0;
    double eveningOutVal = 0.0;
    double morningStockToSheet = 0.0;
    double eveningStockToSheet = 0.0;

    // Shot counts are 0 if roastType is Other Inventory, otherwise parsed
    int throwAwayVal = isOtherInventory ? 0 : (int.tryParse(throwAwayStr) ?? 0);
    int testVal = isOtherInventory ? 0 : (int.tryParse(testStr) ?? 0);
    int eventVal = isOtherInventory ? 0 : (int.tryParse(eventStr) ?? 0);
    int employeeShotVal = isOtherInventory ? 0 : (int.tryParse(employeeShotStr) ?? 0);

    if (isSingleOrigin) {
      morningStockToSheet = double.tryParse(soInStr) ?? 0.0;
      eveningStockToSheet = double.tryParse(soOutStr) ?? 0.0;
    } else if (isOtherInventory) { // NEW Data assignment for Other Inventory
      morningStockToSheet = double.tryParse(lmMorningStockStr) ?? 0.0; // Repurposed for Inventory IN
      eveningStockToSheet = double.tryParse(lmEveningStockStr) ?? 0.0; // Repurposed for Inventory OUT
      // Explicitly clear/set coffee-specific grinder fields to 0 for inventory
      morningInVal = 0.0;
      addOnMorningVal = 0.0;
      addOnAfternoonVal = 0.0;
      eveningOutVal = 0.0;
    } else { // Light/Medium Roasts
      if (isMorningShift) {
        morningInVal = double.tryParse(morningInStr) ?? 0.0;
        addOnMorningVal = double.tryParse(addOnMorningStr) ?? 0.0;
        morningStockToSheet = double.tryParse(lmMorningStockStr) ?? 0.0;
      } else {
        addOnAfternoonVal = double.tryParse(addOnAfternoonStr) ?? 0.0;
        eveningOutVal = double.tryParse(eveningOutStr) ?? 0.0;
        eveningStockToSheet = double.tryParse(lmEveningStockStr) ?? 0.0;
      }
    }

    final newRecord = Record(
      date: date,
      shift: shift,
      roastType: roastType,
      beanName: (isSingleOrigin || isOtherInventory) ? beanName : '', // 'Bean Name' is used for item name for Inventory
      morningIn: morningInVal,
      addOnMorning: addOnMorningVal,
      addOnAfternoon: addOnAfternoonVal,
      eveningOut: eveningOutVal,
      morningStock: morningStockToSheet,
      eveningStock: eveningStockToSheet,
      throwAway: throwAwayVal,
      test: testVal,
      event: eventVal,
      employeeShot: employeeShotVal,
      notes: notes,
    );

    return {
      'success': true,
      'record': newRecord,
    };
  } catch (e) {
    return {
      'success': false,
      'message': "An unexpected error occurred during data parsing: $e",
    };
  }
}

void main() {
  runApp(const CoffeeStockTrackerApp());
}

class CoffeeStockTrackerApp extends StatelessWidget {
  const CoffeeStockTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffee Stock Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 3,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 5,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GoogleSheetService _sheetService = GoogleSheetService();

  List<Record> _dashboardData = [];
  List<Map<String, dynamic>> _historyData = [];
  Record? _currentEditRecord;
  int? _editingRecordIndex;

  Set<String> _beanNameSuggestions = {};
  Set<String> _inventoryNameSuggestions = {}; // already present

  // This function is now responsible for setting the edit state and navigating
  void _editEntry(Record record, int rowIndex) {
    setState(() {
      _currentEditRecord = record;
      _editingRecordIndex = rowIndex;
      _selectedIndex = 1; // Navigate to the "Daily Entry" tab
    });
  }

  void _clearEditState() {
    setState(() {
      _currentEditRecord = null;
      _editingRecordIndex = null;
    });
  }

  Future<void> _refreshAllData() async {
    final dashData = await getDashboardData(_sheetService);
    final histData = await getHistoryData(_sheetService);

    // Use Set to ensure unique names only (no duplicates)
    final Set<String> newBeanSuggestions = {};
    final Set<String> newInventorySuggestions = {};

    for (var recordMap in histData) {
      final Record record = Record.fromMap(recordMap);
      if (record.roastType == 'Single Origin' && record.beanName.isNotEmpty) {
        newBeanSuggestions.add(record.beanName.trim());
      } else if (record.roastType == 'Other Inventory' && record.beanName.isNotEmpty) {
        newInventorySuggestions.add(record.beanName.trim());
      }
    }

    setState(() {
      _dashboardData = dashData;
      _historyData = histData;
      _beanNameSuggestions = newBeanSuggestions;
      _inventoryNameSuggestions = newInventorySuggestions;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    bool connected = await _sheetService.initializeSheet();
    if (!connected) {
      _showSnackbar("Connection Error: Could not connect to Google Sheet.", isSuccess: false);
    }
    await _refreshAllData();
  }

  void _showSnackbar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isSuccess ? Colors.green[600] : Colors.red[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (_selectedIndex == 1) {
        _clearEditState();
      }
      _refreshAllData();
    });
  }

  Future<void> _handleEntrySubmission({
    required String date,
    required String shift,
    required String roastType,
    String beanName = '',
    String morningInStr = '',
    String addOnMorningStr = '',
    String addOnAfternoonStr = '',
    String eveningOutStr = '',
    String lmMorningStockStr = '',
    String lmEveningStockStr = '',
    String soInStr = '',
    String soOutStr = '',
    String throwAwayStr = '0',
    String testStr = '0',
    String eventStr = '0',
    String employeeShotStr = '0',
    String notes = '',
  }) async {
    final validationResult = validateAndPrepareRecord(
      date: date,
      shift: shift,
      roastType: roastType,
      beanName: beanName,
      morningInStr: morningInStr,
      addOnMorningStr: addOnMorningStr,
      addOnAfternoonStr: addOnAfternoonStr,
      eveningOutStr: eveningOutStr,
      lmMorningStockStr: lmMorningStockStr,
      lmEveningStockStr: lmEveningStockStr,
      soInStr: soInStr,
      soOutStr: soOutStr,
      throwAwayStr: throwAwayStr,
      testStr: testStr,
      eventStr: eventStr,
      employeeShotStr: employeeShotStr,
      notes: notes,
    );

    if (!validationResult['success']) {
      _showSnackbar(validationResult['message'], isSuccess: false);
      return;
    }

    final Record recordToSubmit = validationResult['record'];
    bool success = false;

    if (_editingRecordIndex != null) {
      success = await _sheetService.updateExistingRecord(recordToSubmit, _editingRecordIndex!);
      if (success) {
        _showSnackbar("Stock entry updated successfully!", isSuccess: true);
      } else {
        _showSnackbar("Failed to update stock entry in Google Sheet.", isSuccess: false);
      }
    } else {
      success = await _sheetService.appendRecord(recordToSubmit);
      if (success) {
        _showSnackbar("Stock entry added successfully!", isSuccess: true);
      } else {
        _showSnackbar("Failed to add stock entry to Google Sheet.", isSuccess: false);
      }
    }

    if (success) {
      _clearEditState();
      await _refreshAllData();
      setState(() {
        _selectedIndex = 0;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(_selectedIndex)),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardContent(
            dashboardData: _dashboardData,
            refreshDashboardData: _refreshAllData,
            // Pass the entire _historyData and the editEntry callback
            allHistoryData: _historyData,
            onTapDashboardItem: _editEntry,
          ),
          DailyEntryContent(
            submitEntry: _handleEntrySubmission,
            currentEditRecord: _currentEditRecord,
            clearEditState: _clearEditState,
            goToDashboard: () {
              setState(() {
                _selectedIndex = 0;
                _clearEditState();
              });
            },
            beanNameSuggestions: _beanNameSuggestions.toList(),
            inventoryNameSuggestions: _inventoryNameSuggestions.toList(), // pass inventory suggestions
          ),
          HistoryContent(
            historyData: _historyData,
            refreshHistoryData: _refreshAllData,
            editEntry: _editEntry,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline_rounded),
            label: 'Add Entry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return "Coffee Stock Tracker";
      case 1:
        return "Daily Stock Entry";
      case 2:
        return "Stock History";
      default:
        return "Coffee Stock Tracker";
    }
  }
}

// --- Dashboard Content Widget ---
class DashboardContent extends StatefulWidget {
  final List<Record> dashboardData;
  final Future<void> Function() refreshDashboardData;
  final List<Map<String, dynamic>> allHistoryData; // Add this to access full history with row index
  final void Function(Record record, int rowIndex) onTapDashboardItem; // New callback for tapping

  const DashboardContent({
    super.key,
    required this.dashboardData,
    required this.refreshDashboardData,
    required this.allHistoryData, // Initialize
    required this.onTapDashboardItem, // Initialize
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.refreshDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text(
            "Current Stock Overview",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (widget.dashboardData.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "No stock data available. Add an entry!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ...widget.dashboardData.map((item) {
              String coffeeName;
              if (item.roastType == 'Single Origin' || item.roastType == 'Other Inventory') {
                coffeeName = "${item.roastType}: ${item.beanName}";
              } else {
                coffeeName = item.roastType;
              }

              String mainStockAmountDisplay = 'N/A';
              String grinderAmountDisplay = 'N/A';
              Color amountColorGrinder = Colors.green[600]!;
              Color amountColorMain = Colors.blueGrey[900]!;

              // Overall stock
              double overallStockAmount = item.eveningStock;
              if (overallStockAmount == 0) { // If evening stock is 0, use morning stock
                 overallStockAmount = item.morningStock;
              }
              mainStockAmountDisplay = formatQuantityDisplay(overallStockAmount, unit: 'g', roastType: item.roastType);

              // Overall stock color based on quantity and type
              final double? parsedMainStockAmount = double.tryParse(mainStockAmountDisplay.replaceAll('g', '').replaceAll('N/A', '0'));
              if (parsedMainStockAmount != null && parsedMainStockAmount > 0) {
                if (parsedMainStockAmount <= 1000 && item.roastType != 'Other Inventory') { // Low coffee stock
                  amountColorMain = Colors.orange[700]!;
                }
                if (parsedMainStockAmount <= 500 && item.roastType != 'Other Inventory') { // Very low coffee stock
                  amountColorMain = Colors.red[500]!;
                }
              } else if (parsedMainStockAmount == 0) {
                 amountColorMain = Colors.grey; // Grey for N/A or 0
              }

              // Grinder/In-use calculation (Feature 1)
              if (item.roastType != 'Single Origin' && item.roastType != 'Other Inventory') { // Only for Light/Medium Roasts
                double grinderCalculation = 0.0;
                if (item.shift == 'Morning') {
                  grinderCalculation = item.morningIn + item.addOnMorning;
                } else if (item.shift == 'Evening') {
                  grinderCalculation = item.eveningOut + item.addOnAfternoon;
                }
                grinderAmountDisplay = formatQuantityDisplay(grinderCalculation, unit: 'g', roastType: item.roastType);

                final double? parsedGrinderAmount = double.tryParse(grinderAmountDisplay.replaceAll('g', '').replaceAll('N/A', '0'));
                if (parsedGrinderAmount != null && parsedGrinderAmount <= 100 && parsedGrinderAmount > 0) {
                  amountColorGrinder = Colors.red[500]!;
                } else if (parsedGrinderAmount == 0) {
                  amountColorGrinder = Colors.grey;
                }
              } else {
                grinderAmountDisplay = "N/A"; // Not applicable for SO or Other Inventory
              }

              // Find the corresponding record in historyData to get the rowIndex
              // This is a heuristic, assuming the dashboard item corresponds to the *latest* entry
              // for that roast type/bean name. A more robust solution might involve storing
              // the rowIndex directly in the Record model if fetched from Sheets.
              final Map<String, dynamic>? recordInHistory = widget.allHistoryData.firstWhere(
                (historyItem) {
                  final historyRecord = Record.fromMap(historyItem);
                  return historyRecord.date == item.date &&
                         historyRecord.shift == item.shift &&
                         historyRecord.roastType == item.roastType &&
                         historyRecord.beanName == item.beanName;
                },
                orElse: () => {}, // Return an empty map if not found
              );

              final int? rowIndexForEdit = recordInHistory?['__rowIndex'] as int?;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell( // Use InkWell for tap feedback
                  onTap: () {
                    if (rowIndexForEdit != null) {
                      widget.onTapDashboardItem(item, rowIndexForEdit);
                    } else {
                      // Optionally show a snackbar or log if the record can't be found for editing
                      debugPrint("Could not find row index for dashboard item: ${item.roastType} - ${item.beanName}");
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coffeeName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                        ),
                        Text(
                          "Last updated: ${item.date} (${item.shift})",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Overall: $mainStockAmountDisplay",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: amountColorMain,
                                        ),
                                  ),
                                  Text("overall stock", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                                ],
                              ),
                            ),
                            if (item.roastType != 'Single Origin' && item.roastType != 'Other Inventory')
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Grinder: $grinderAmountDisplay",
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: amountColorGrinder,
                                          ),
                                    ),
                                    Text("in grinder", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (item.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "Notes: ${item.notes}",
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[500]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- Daily Entry Content Widget ---
class DailyEntryContent extends StatefulWidget {
  final Future<void> Function({
    required String date,
    required String shift,
    required String roastType,
    String beanName,
    String morningInStr,
    String addOnMorningStr,
    String addOnAfternoonStr,
    String eveningOutStr,
    String lmMorningStockStr,
    String lmEveningStockStr,
    String soInStr,
    String soOutStr,
    String throwAwayStr,
    String testStr,
    String eventStr,
    String employeeShotStr,
    String notes,
  }) submitEntry;
  final Record? currentEditRecord;
  final VoidCallback clearEditState;
  final VoidCallback goToDashboard;
  final List<String> beanNameSuggestions;
  final List<String> inventoryNameSuggestions; // add this

  const DailyEntryContent({
    super.key,
    required this.submitEntry,
    this.currentEditRecord,
    required this.clearEditState,
    required this.goToDashboard,
    required this.beanNameSuggestions,
    required this.inventoryNameSuggestions, // add this
  });

  @override
  State<DailyEntryContent> createState() => _DailyEntryContentState();
}

class _DailyEntryContentState extends State<DailyEntryContent> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _beanNameController = TextEditingController();
  final TextEditingController _morningInController = TextEditingController();
  final TextEditingController _addOnMorningController = TextEditingController();
  final TextEditingController _addOnAfternoonController = TextEditingController();
  final TextEditingController _eveningOutController = TextEditingController();
  final TextEditingController _lmMorningStockController = TextEditingController();
  final TextEditingController _lmEveningStockController = TextEditingController();
  final TextEditingController _soInController = TextEditingController();
  final TextEditingController _soOutController = TextEditingController();
  final TextEditingController _throwAwayController = TextEditingController(text: '0');
  final TextEditingController _testController = TextEditingController(text: '0');
  final TextEditingController _eventController = TextEditingController(text: '0');
  final TextEditingController _employeeShotController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  String _selectedShift = 'Morning';
  String? _selectedRoastType = 'Light Roast'; // Initialize here or in initState
  bool _isSingleOrigin = false;
  bool _isOtherInventory = false;
  bool _isMorningShift = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void didUpdateWidget(covariant DailyEntryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentEditRecord != oldWidget.currentEditRecord) {
      _initializeForm();
    }
  }

  void _initializeForm() {
    if (widget.currentEditRecord != null) {
      _dateController.text = widget.currentEditRecord!.date;
      _selectedShift = widget.currentEditRecord!.shift;
      _selectedRoastType = widget.currentEditRecord!.roastType;
      _beanNameController.text = widget.currentEditRecord!.beanName;

      _morningInController.text = widget.currentEditRecord!.morningIn == 0.0 ? '' : widget.currentEditRecord!.morningIn.toString();
      _addOnMorningController.text = widget.currentEditRecord!.addOnMorning == 0.0 ? '' : widget.currentEditRecord!.addOnMorning.toString();
      _addOnAfternoonController.text = widget.currentEditRecord!.addOnAfternoon == 0.0 ? '' : widget.currentEditRecord!.addOnAfternoon.toString();
      _eveningOutController.text = widget.currentEditRecord!.eveningOut == 0.0 ? '' : widget.currentEditRecord!.eveningOut.toString();
      _lmMorningStockController.text = widget.currentEditRecord!.morningStock == 0.0 ? '' : widget.currentEditRecord!.morningStock.toString();
      _lmEveningStockController.text = widget.currentEditRecord!.eveningStock == 0.0 ? '' : widget.currentEditRecord!.eveningStock.toString();
      _soInController.text = widget.currentEditRecord!.morningStock == 0.0 ? '' : widget.currentEditRecord!.morningStock.toString();
      _soOutController.text = widget.currentEditRecord!.eveningStock == 0.0 ? '' : widget.currentEditRecord!.eveningStock.toString();

      _throwAwayController.text = widget.currentEditRecord!.throwAway.toString();
      _testController.text = widget.currentEditRecord!.test.toString();
      _eventController.text = widget.currentEditRecord!.event.toString();
      _employeeShotController.text = widget.currentEditRecord!.employeeShot.toString();
      _notesController.text = widget.currentEditRecord!.notes;
    } else {
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedShift = 'Morning';
      _selectedRoastType = 'Light Roast'; // Default to a coffee type
      _beanNameController.clear();
      _morningInController.clear();
      _addOnMorningController.clear();
      _addOnAfternoonController.clear();
      _eveningOutController.clear();
      _lmMorningStockController.clear();
      _lmEveningStockController.clear();
      _soInController.clear();
      _soOutController.clear();
      _throwAwayController.text = '0';
      _testController.text = '0';
      _eventController.text = '0';
      _employeeShotController.text = '0';
      _notesController.clear();
    }
    _updateFieldVisibility();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _beanNameController.dispose();
    _morningInController.dispose();
    _addOnMorningController.dispose();
    _addOnAfternoonController.dispose();
    _eveningOutController.dispose();
    _lmMorningStockController.dispose();
    _lmEveningStockController.dispose();
    _soInController.dispose();
    _soOutController.dispose();
    _throwAwayController.dispose();
    _testController.dispose();
    _eventController.dispose();
    _employeeShotController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _adjustDate(int days) {
    _dateController.text = adjustDate(_dateController.text, days);
  }

  void _updateFieldVisibility() {
    if (mounted) {
      setState(() {
        _isSingleOrigin = _selectedRoastType == 'Single Origin';
        _isOtherInventory = _selectedRoastType == 'Other Inventory';
        _isMorningShift = _selectedShift == 'Morning';

        // Clear irrelevant fields based on Roast Type
        if (!_isSingleOrigin && !_isOtherInventory) { // Coffee Beans
          _beanNameController.clear();
          _soInController.clear();
          _soOutController.clear();
        } else if (_isSingleOrigin) { // Single Origin
          _morningInController.clear();
          _addOnMorningController.clear();
          _addOnAfternoonController.clear();
          _eveningOutController.clear();
          _lmMorningStockController.clear(); // Clear LM stock fields for SO
          _lmEveningStockController.clear(); // Clear LM stock fields for SO
        } else if (_isOtherInventory) { // Other Inventory
          _morningInController.clear();
          _addOnMorningController.clear();
          _addOnAfternoonController.clear();
          _eveningOutController.clear();
          _soInController.clear(); // Clear SO stock fields for Other Inventory
          _soOutController.clear(); // Clear SO stock fields for Other Inventory
        }

        // Clear irrelevant fields based on Shift
        if (_isMorningShift) {
          _addOnAfternoonController.clear();
          _eveningOutController.clear();
          if (!_isSingleOrigin && !_isOtherInventory) _lmEveningStockController.clear(); // Clear LM Evening stock for LM morning
          if (_isSingleOrigin) _soOutController.clear(); // Clear SO Out for SO morning
          if (_isOtherInventory) _lmEveningStockController.clear(); // Clear Inventory Out for Inventory morning
        } else { // Evening Shift
          _morningInController.clear();
          _addOnMorningController.clear();
          if (!_isSingleOrigin && !_isOtherInventory) _lmMorningStockController.clear(); // Clear LM Morning stock for LM evening
          if (_isSingleOrigin) _soInController.clear(); // Clear SO In for SO evening
          if (_isOtherInventory) _lmMorningStockController.clear(); // Clear Inventory In for Inventory evening
        }

        // Shot-related fields are hidden for Other Inventory
        if (_isOtherInventory) {
          _throwAwayController.text = '0';
          _testController.text = '0';
          _eventController.text = '0';
          _employeeShotController.text = '0';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which suggestions list to use based on selected roast type
    List<String> currentSuggestions = [];
    String beanNameLabel = 'Bean Name (if SO)';
    if (_selectedRoastType == 'Single Origin') {
      // Show unique, sorted names
      currentSuggestions = widget.beanNameSuggestions.toSet().toList()..sort();
      beanNameLabel = 'Bean Name (e.g., Kenya AA)';
    } else if (_selectedRoastType == 'Other Inventory') {
      currentSuggestions = widget.inventoryNameSuggestions.toSet().toList()..sort();
      beanNameLabel = 'Item Name (e.g., Milk, Banana)';
    }

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left),
              tooltip: "Previous Day",
              onPressed: () => setState(() => _adjustDate(-1)),
            ),
            Expanded(
              child: TextField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: "Date"),
                readOnly: true,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              tooltip: "Next Day",
              onPressed: () => setState(() => _adjustDate(1)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          "Shift",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey[800],
              ),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text("Morning"),
                value: "Morning",
                groupValue: _selectedShift,
                onChanged: (value) {
                  setState(() {
                    _selectedShift = value!;
                    _updateFieldVisibility();
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text("Evening"),
                value: "Evening",
                groupValue: _selectedShift,
                onChanged: (value) {
                  setState(() {
                    _selectedShift = value!;
                    _updateFieldVisibility();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: _selectedRoastType,
          decoration: const InputDecoration(labelText: "Roast Type"),
          items: const [
            DropdownMenuItem(value: "Light Roast", child: Text("Light Roast")),
            DropdownMenuItem(value: "Medium Roast", child: Text("Medium Roast")),
            DropdownMenuItem(value: "Single Origin", child: Text("Single Origin")),
            DropdownMenuItem(value: "Other Inventory", child: Text("Other Inventory")), // NEW Roast Type
          ],
          onChanged: (value) {
            setState(() {
              _selectedRoastType = value;
              _updateFieldVisibility();
            });
          },
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: _isSingleOrigin || _isOtherInventory,
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              // Show all options if field is empty or focused
              if (textEditingValue.text == '') {
                return currentSuggestions;
              }
              return currentSuggestions.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            displayStringForOption: (option) => option,
            onSelected: (String selection) {
              _beanNameController.text = selection;
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
              // Keep _beanNameController in sync with the field
              textEditingController.text = _beanNameController.text;
              textEditingController.selection = TextSelection.fromPosition(
                TextPosition(offset: textEditingController.text.length),
              );
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: beanNameLabel,
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    onSelected: (String value) {
                      textEditingController.text = value;
                      _beanNameController.text = value;
                    },
                    itemBuilder: (BuildContext context) {
                      return currentSuggestions.map((String value) {
                        return PopupMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList();
                    },
                  ),
                ),
                onChanged: (value) {
                  _beanNameController.text = value;
                },
                onSubmitted: (value) {
                  onFieldSubmitted();
                },
              );
            },
            optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: SizedBox(
                    height: 200.0,
                    width: 300.0,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return ListTile(
                          title: Text(option),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 15),

        // --- Coffee Beans Specific Fields (Hidden for Other Inventory) ---
        Visibility(
          visible: !_isSingleOrigin && !_isOtherInventory && _isMorningShift,
          child: TextField(
            controller: _morningInController,
            decoration: const InputDecoration(
              labelText: "Morning In (g) - Grinder start",
              helperText: "Amount in grinder at start of morning shift (Light/Medium)",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: !_isSingleOrigin && !_isOtherInventory && _isMorningShift,
          child: TextField(
            controller: _addOnMorningController,
            decoration: const InputDecoration(
              labelText: "Add On Morning (g)",
              helperText: "Additional beans added to grinder during morning (Light/Medium)",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: !_isSingleOrigin && !_isOtherInventory && !_isMorningShift,
          child: TextField(
            controller: _addOnAfternoonController,
            decoration: const InputDecoration(
              labelText: "Add On Afternoon (g)",
              helperText: "Additional beans added to grinder during afternoon (Light/Medium)",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: !_isSingleOrigin && !_isOtherInventory && !_isMorningShift,
          child: TextField(
            controller: _eveningOutController,
            decoration: const InputDecoration(
              labelText: "Evening Out (g) - Remaining in grinder",
              helperText: "Amount remaining in grinder at end of evening shift (Light/Medium)",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: !_isSingleOrigin && !_isOtherInventory && _isMorningShift, // Only for Light/Medium Morning
          child: TextField(
            controller: _lmMorningStockController,
            decoration: const InputDecoration(
              labelText: "Light/Medium Overall Stock (IN)",
              helperText: "Total overall stock at morning for Light/Medium (includes new bags)",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: !_isSingleOrigin && !_isOtherInventory && !_isMorningShift, // Only for Light/Medium Evening
          child: TextField(
            controller: _lmEveningStockController,
            decoration: const InputDecoration(
              labelText: "Light/Medium Overall Stock (OUT)",
              helperText: "Total overall stock at evening for Light/Medium",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),

        // --- Single Origin / Other Inventory Specific Fields ---
        Visibility(
          visible: (_isSingleOrigin || _isOtherInventory) && _isMorningShift,
          child: TextField(
            controller: _soInController,
            decoration: InputDecoration(
              labelText: "${_selectedRoastType} Total Stock (IN)",
              helperText: "Total ${_selectedRoastType} stock at start of morning shift (includes new deliveries)",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        Visibility(
          visible: (_isSingleOrigin || _isOtherInventory) && !_isMorningShift,
          child: TextField(
            controller: _soOutController,
            decoration: InputDecoration(
              labelText: "${_selectedRoastType} Total Stock (OUT)",
              helperText: "Total ${_selectedRoastType} stock at end of evening shift",
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),

        // --- Shot-related fields (Hidden for Other Inventory) ---
        Visibility(
          visible: !_isOtherInventory,
          child: Column(
            children: [
              const Divider(height: 20, color: Colors.blueGrey),
              Text(
                "Other Metrics (Number of Shots)",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _throwAwayController,
                decoration: const InputDecoration(
                  labelText: "Throw Away (Shot)",
                  helperText: "Number of shots discarded (e.g., undrinkable, bad extraction)",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _testController,
                decoration: const InputDecoration(
                  labelText: "Test (Shot)",
                  helperText: "Number of shots used for testing/calibration",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: "Event (Shot)",
                  helperText: "Number of shots used for activities or events",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _employeeShotController,
                decoration: const InputDecoration(
                  labelText: "Employee (Shot)",
                  helperText: "Number of shots related to employee activity (e.g., training, personal use)",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
        const Divider(height: 20, color: Colors.blueGrey),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: "Notes"),
          maxLines: 5,
          minLines: 3,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel_rounded),
                label: const Text("Cancel"),
                onPressed: () {
                  widget.clearEditState();
                  widget.goToDashboard();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: Text(widget.currentEditRecord == null ? "Save Daily Entry" : "Update Entry"),
                onPressed: () {
                  widget.submitEntry(
                    date: _dateController.text,
                    shift: _selectedShift,
                    roastType: _selectedRoastType!,
                    beanName: _beanNameController.text,
                    morningInStr: _morningInController.text,
                    addOnMorningStr: _addOnMorningController.text,
                    addOnAfternoonStr: _addOnAfternoonController.text,
                    eveningOutStr: _eveningOutController.text,
                    lmMorningStockStr: _lmMorningStockController.text,
                    lmEveningStockStr: _lmEveningStockController.text,
                    soInStr: _soInController.text,
                    soOutStr: _soOutController.text,
                    throwAwayStr: _throwAwayController.text,
                    testStr: _testController.text,
                    eventStr: _eventController.text,
                    employeeShotStr: _employeeShotController.text,
                    notes: _notesController.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- History Content Widget ---
class HistoryContent extends StatefulWidget {
  final List<Map<String, dynamic>> historyData;
  final Future<void> Function() refreshHistoryData;
  final void Function(Record record, int rowIndex) editEntry;

  const HistoryContent({
    super.key,
    required this.historyData,
    required this.refreshHistoryData,
    required this.editEntry,
  });

  @override
  State<HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<HistoryContent> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.refreshHistoryData,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            children: [
              Text(
                "All Recorded Entries",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (widget.historyData.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "No history data available. Add an entry to see it here!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: DataTable(
                      columnSpacing: 10,
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.hovered)) {
                            return Colors.grey[50];
                          }
                          return Colors.white;
                        },
                      ),
                      headingRowColor: MaterialStateProperty.all(Colors.blueGrey[100]),
                      border: TableBorder.all(
                        color: Colors.grey[200]!,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      columns: const [
                        DataColumn(label: Text("Date", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Shift", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Coffee/Item", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Morning In (Grinder)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Add On Morning (Grinder)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Add On Afternoon (Grinder)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Evening Out (Grinder)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Overall Stock", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Throw Away (Shot)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Test (Shot)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Event (Shot)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Employee (Shot)", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Notes/Comments", style: TextStyle(color: Colors.blueGrey))),
                        DataColumn(label: Text("Actions", style: TextStyle(color: Colors.blueGrey))),
                      ],
                      rows: widget.historyData.map((itemMap) {
                        final item = Record.fromMap(itemMap);
                        final int rowIndex = itemMap['__rowIndex'];

                        String coffeeItemName;
                        if (item.roastType == 'Single Origin' || item.roastType == 'Other Inventory') {
                          coffeeItemName = item.beanName;
                        } else {
                          coffeeItemName = item.roastType;
                        }

                        String mainStockVal = formatQuantityDisplay(
                          item.shift == 'Morning' ? item.morningStock : item.eveningStock,
                          unit: 'g',
                          roastType: item.roastType,
                        );

                        String morningInDisplay = item.roastType != 'Single Origin' && item.roastType != 'Other Inventory'
                            ? formatQuantityDisplay(item.morningIn, unit: 'g', roastType: item.roastType)
                            : 'N/A';
                        String addOnMorningDisplay = item.roastType != 'Single Origin' && item.roastType != 'Other Inventory'
                            ? formatQuantityDisplay(item.addOnMorning, unit: 'g', roastType: item.roastType)
                            : 'N/A';
                        String addOnAfternoonDisplay = item.roastType != 'Single Origin' && item.roastType != 'Other Inventory'
                            ? formatQuantityDisplay(item.addOnAfternoon, unit: 'g', roastType: item.roastType)
                            : 'N/A';
                        String eveningOutDisplay = item.roastType != 'Single Origin' && item.roastType != 'Other Inventory'
                            ? formatQuantityDisplay(item.eveningOut, unit: 'g', roastType: item.roastType)
                            : 'N/A';

                        String throwAwayDisplay = item.roastType != 'Other Inventory' ? formatQuantityDisplay(item.throwAway, unit: 'shot') : 'N/A';
                        String testDisplay = item.roastType != 'Other Inventory' ? formatQuantityDisplay(item.test, unit: 'shot') : 'N/A';
                        String eventDisplay = item.roastType != 'Other Inventory' ? formatQuantityDisplay(item.event, unit: 'shot') : 'N/A';
                        String employeeShotDisplay = item.roastType != 'Other Inventory' ? formatQuantityDisplay(item.employeeShot, unit: 'shot') : 'N/A';


                        return DataRow(
                          cells: [
                            DataCell(Text(item.date)),
                            DataCell(Text(item.shift)),
                            DataCell(Text(coffeeItemName)),
                            DataCell(Text(morningInDisplay)),
                            DataCell(Text(addOnMorningDisplay)),
                            DataCell(Text(addOnAfternoonDisplay)),
                            DataCell(Text(eveningOutDisplay)),
                            DataCell(Text(mainStockVal)),
                            DataCell(Text(throwAwayDisplay)),
                            DataCell(Text(testDisplay)),
                            DataCell(Text(eventDisplay)),
                            DataCell(Text(employeeShotDisplay)),
                            DataCell(Text(item.notes.isNotEmpty ? item.notes : 'N/A')),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: "Edit Entry",
                                onPressed: () {
                                  widget.editEntry(item, rowIndex);
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
