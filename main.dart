import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:convert';

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
  String? updateTime; // New field for Update Time
  int? rowIndex; // New field to store the row index from Google Sheet
  double? minimumStock; // NEW: Minimum stock value for the item

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
    this.updateTime, // Initialize the new field
    this.rowIndex, // Initialize the new rowIndex field
    this.minimumStock, // NEW: Initialize minimumStock
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
      updateTime: map['Update Time']?.toString(), // Parse the new field
      rowIndex: map['__rowIndex'] as int?, // Assign rowIndex from the map
      minimumStock: double.tryParse(map['Min Stock Value']?.toString() ?? ''), // NEW: Parse Min Stock Value
    );
  }
}

// --- Google Sheets Configuration ---
const List<String> expectedHeaders = [
  'Date', 'Shift', 'Roast Type', 'Bean Name (if SO)', 'Morning In (g)',
  'Add On Morning (g)', 'Add On Afternoon (g)', 'Evening Out (g)',
  'Morning Stock (g)', 'Evening Stock (g)', 'Throw Away (Shot)',
  'Test (Shot)', 'Event (Shot)', 'Employee (Shot)', 'Notes/Comments',
  'Update Time', // New column header
  'Min Stock Value', // NEW: New column for minimum stock
];

// --- GoogleSheetService Class ---
class GoogleSheetService {
  sheets.SheetsApi? _sheetsApi;
  String? _spreadsheetId;

  final String googleSheetName = 'Daily Checklist';
  final String worksheetName = 'Copy of Coffee Stock Tracker Table';

  Future<bool> initializeSheet() async {
    try {
      // Load service account key from assets
      final String jsonCredentialsString = await rootBundle.loadString('assets/service_account_key.json');
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(jsonCredentialsString);

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
          final List<String> currentHeaders = currentFirstRow[0].map((e) => e.toString()).toList();
          headersMatch = true;
          for (int i = 0; i < expectedHeaders.length; i++) {
            if (currentHeaders[i] != expectedHeaders[i]) {
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
      // Adjusted range to include the new column. 'Q' is the 17th letter.
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A:Q',
      );
      // Explicitly cast to List<List<dynamic>> to handle Object? types
      final List<List<dynamic>> allValues = (response.values ?? []).map((row) => row.map((e) => e as dynamic).toList()).toList();


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
            record[headers[colIdx]] = ''; // Ensure all headers have a value, even if empty
          }
        }

        // Parse numerical fields, ensuring they are correctly typed
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
        // NEW: Parse Min Stock Value
        record['Min Stock Value'] = double.tryParse(record['Min Stock Value']?.toString() ?? '');

        record['__rowIndex'] = i + 2; // +2 because sheet is 1-indexed and has a header row
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
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()), // Auto-set Update Time
        record.minimumStock, // NEW: Include minimumStock
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
      // Re-verify column order: Date, Shift, Roast Type, Bean Name, Morning In, Add On Morning, Add On Afternoon, Evening Out, Morning Stock, Evening Stock, Throw Away, Test, Event, Employee, Notes, Update Time, Min Stock Value
      final List<dynamic> alignedRowData = [
        record.date,
        record.shift,
        record.roastType,
        record.beanName,
        record.morningIn,
        record.addOnMorning,
        record.addOnAfternoon,
        record.eveningOut,
        record.morningStock, // Correct order for Morning Stock
        record.eveningStock, // Correct order for Evening Stock
        record.throwAway,
        record.test,
        record.event,
        record.employeeShot,
        record.notes,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()), // Auto-update time
        record.minimumStock, // NEW: Include minimumStock
      ];


      final String range = '$worksheetName!A$rowIndex:${String.fromCharCode(65 + expectedHeaders.length - 1)}$rowIndex';

      await _sheetsApi!.spreadsheets.values.update(
        sheets.ValueRange(values: [alignedRowData]), // Use alignedRowData
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
  if (roastType == 'Other Inventory' || unit == 'units') { // Added unit == 'units' for general non-gram items
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

    // Use tryParse to handle potentially invalid date formats gracefully
    final currentDate = DateTime.tryParse(item.date) ?? DateTime(1900); // Fallback to a very old date

    if (!latestStock.containsKey(itemKey)) {
      latestStock[itemKey] = item;
    } else {
      final existingItem = latestStock[itemKey]!;
      final existingDate = DateTime.tryParse(existingItem.date) ?? DateTime(1900); // Fallback to a very old date

      // Prioritize by date (newer date is always preferred)
      if (currentDate.isAfter(existingDate)) {
        latestStock[itemKey] = item;
      } else if (currentDate.isAtSameMomentAs(existingDate)) {
        // If same date, use updateTime as the primary tie-breaker
        final currentUpdateTime = DateTime.tryParse(item.updateTime ?? '');
        final existingUpdateTime = DateTime.tryParse(existingItem.updateTime ?? '');

        // If both have update times, the newer update time wins
        if (currentUpdateTime != null && existingUpdateTime != null) {
          if (currentUpdateTime.isAfter(existingUpdateTime)) {
            latestStock[itemKey] = item;
          }
          // If current is older or same, keep existing (no change needed)
        }
        // If only current has update time, current wins (it's a newer update)
        else if (currentUpdateTime != null && existingUpdateTime == null) {
          latestStock[itemKey] = item;
        }
        // If only existing has update time, existing wins (it's a recorded update vs. a non-updated or unparseable current)
        // No 'else if' here, as the default will be to keep existing if none of the above conditions are met for 'item'
        else {
          // If neither has a valid update time (or both are null), fall back to shift and stock data
          // Prioritize Evening over Morning if shifts are different
          if (item.shift == 'Evening' && existingItem.shift == 'Morning') {
            latestStock[itemKey] = item;
          }
          // If shifts are the same, or current is Morning and existing is Evening,
          // then keep the one with more "stock" data as a final tie-breaker.
          else if (item.shift == existingItem.shift) {
             // Prefer the one with actual stock values if the other has zero
             if (item.eveningStock != 0 && existingItem.eveningStock == 0) {
                 latestStock[itemKey] = item;
             } else if (item.morningStock != 0 && existingItem.morningStock == 0 && item.shift == 'Morning') {
                 latestStock[itemKey] = item;
             }
             // Or prefer the one with a bean name if applicable
             else if ((item.roastType == 'Single Origin' || item.roastType == 'Other Inventory')
                 && item.beanName.isNotEmpty && existingItem.beanName.isEmpty) {
                 latestStock[itemKey] = item;
             }
          }
        }
      }
    }
  }

  List<Record> displayStock = latestStock.values.toList();

  // --- Apply Dashboard Filtering Logic ---
  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));

  displayStock = displayStock.where((record) {
    // Always show Light Roast and Medium Roast
    if (record.roastType == 'Light Roast' || record.roastType == 'Medium Roast') {
      return true;
    }

    // Filter out if not updated within 7 days
    final recordDate = DateTime.tryParse(record.date);
    if (recordDate != null && recordDate.isBefore(sevenDaysAgo)) {
      return false; // Exclude if older than 7 days
    }

    // Filter out if stock is empty (both evening and morning stock are 0)
    // if (record.eveningStock == 0 && record.morningStock == 0) { // Keep this logic if you want to hide if stock is literally zero
    //   return false;
    // }

    return true; // Keep the record if it passes all filters or is an exception
  }).toList();
  // --- End Dashboard Filtering Logic ---

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
    // Use tryParse with a fallback to handle potentially invalid date formats
    final dateA = DateTime.tryParse(a['Date']?.toString() ?? '') ?? DateTime(1900);
    final dateB = DateTime.tryParse(b['Date']?.toString() ?? '') ?? DateTime(1900);

    int dateCompare = dateB.compareTo(dateA); // Sort by date descending (newest first)
    if (dateCompare != 0) return dateCompare;

    // For same date, Morning (0) comes before Evening (1)
    int shiftA = (a['Shift']?.toString() == 'Morning') ? 0 : 1;
    int shiftB = (b['Shift']?.toString() == 'Morning') ? 0 : 1;
    int shiftCompare = shiftA.compareTo(shiftB);
    if (shiftCompare != 0) return shiftCompare;

    // For same date and shift, use Update Time (newest first)
    final updateTimeA = DateTime.tryParse(a['Update Time']?.toString() ?? '');
    final updateTimeB = DateTime.tryParse(b['Update Time']?.toString() ?? '');

    if (updateTimeA != null && updateTimeB != null) {
      return updateTimeB.compareTo(updateTimeA); // Newest update time first
    } else if (updateTimeA != null) {
      return -1; // A has update time, B doesn't, A comes first
    } else if (updateTimeB != null) {
      return 1; // B has update time, A doesn't, B comes first
    }
    return 0; // No update time for either, maintain original relative order
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
  String minStockStr = '', // NEW: Min Stock Value
}) {
  final List<String> validationErrors = [];

  if (date.isEmpty) validationErrors.add("Date");
  if (shift.isEmpty) validationErrors.add("Shift");
  if (roastType.isEmpty) validationErrors.add("Roast Type");

  final bool isSingleOrigin = roastType == 'Single Origin';
  final bool isOtherInventory = roastType == 'Other Inventory';
  final bool isMorningShift = shift == 'Morning';

  if (isSingleOrigin || isOtherInventory) {
    if (beanName.isEmpty) validationErrors.add(isOtherInventory ? "Item Name" : "Bean Name");
  }

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


  if (isSingleOrigin || isOtherInventory) {
    if (isMorningShift && soInStr.isEmpty) {
      validationErrors.add("${isOtherInventory ? 'Inventory' : 'Single Origin'} Total Stock (IN)");
    } else if (!isMorningShift && soOutStr.isEmpty) {
      validationErrors.add("${isOtherInventory ? 'Inventory' : 'Single Origin'} Total Stock (OUT)");
    }
  } else {
    if (isMorningShift) {
      if (morningInStr.isEmpty) validationErrors.add("Morning In (g) - Grinder");
      if (lmMorningStockStr.isEmpty) validationErrors.add("Light/Medium Overall Stock (IN)");
    } else {
      if (eveningOutStr.isEmpty) validationErrors.add("Evening Out (g) - Grinder");
      if (lmEveningStockStr.isEmpty) validationErrors.add("Light/Medium Overall Stock (OUT)");
    }
  }

  // NEW: Validate Minimum Stock
  if (minStockStr.isNotEmpty && double.tryParse(minStockStr) == null) {
    validationErrors.add("Minimum Stock must be a valid number");
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
    double? minStockVal = double.tryParse(minStockStr); // NEW: Parse minimum stock

    int throwAwayVal = isOtherInventory ? 0 : (int.tryParse(throwAwayStr) ?? 0);
    int testVal = isOtherInventory ? 0 : (int.tryParse(testStr) ?? 0);
    int eventVal = isOtherInventory ? 0 : (int.tryParse(eventStr) ?? 0);
    int employeeShotVal = isOtherInventory ? 0 : (int.tryParse(employeeShotStr) ?? 0);

    if (isSingleOrigin || isOtherInventory) {
      morningStockToSheet = double.tryParse(soInStr) ?? 0.0;
      eveningStockToSheet = double.tryParse(soOutStr) ?? 0.0;
      morningInVal = 0.0;
      addOnMorningVal = 0.0;
      addOnAfternoonVal = 0.0;
      eveningOutVal = 0.0;
    } else {
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
      beanName: (isSingleOrigin || isOtherInventory) ? beanName : '',
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
      minimumStock: minStockVal, // NEW: Assign minimumStock
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
  Set<String> _inventoryNameSuggestions = {};

  // --- MainScreenState (modified _editEntry for clarity) ---
  void _editEntry(Record record, int rowIndex) {
    final DateTime now = DateTime.now();
    final String currentDate = DateFormat('yyyy-MM-dd').format(now);
    final String currentShift = (now.hour < 12) ? 'Morning' : 'Evening'; // Determine current shift for new entry template

    // Determine if the last update was within the last hour
    bool shouldEditExistingFullRecord = false;
    if (record.updateTime != null) {
      final DateTime? lastUpdateTime = DateTime.tryParse(record.updateTime!);
      if (lastUpdateTime != null) {
        final Duration difference = now.difference(lastUpdateTime);
        if (difference.inHours < 1) { // Check if difference is less than 1 hour
          shouldEditExistingFullRecord = true;
        }
      }
    }

    Record recordToPass;
    int? rowIndexToPass;

    if (shouldEditExistingFullRecord) {
      // If within 1 hour, truly edit the existing record.
      // Pass the original 'record' as is, including its date, shift, and rowIndex.
      recordToPass = record;
      rowIndexToPass = rowIndex;
    } else {
      // If not within 1 hour, treat it as a new entry template.
      // Create a new Record object with current date/shift, but copy roastType/beanName.
      recordToPass = Record(
        date: currentDate, // Set to current date
        shift: currentShift, // Set to current shift based on time
        roastType: record.roastType,
        beanName: record.beanName,
        // Reset other fields for a new entry template
        morningIn: 0.0,
        addOnMorning: 0.0,
        addOnAfternoon: 0.0,
        eveningOut: 0.0,
        morningStock: 0.0,
        eveningStock: 0.0,
        throwAway: 0,
        test: 0,
        event: 0,
        employeeShot: 0,
        notes: '',
        updateTime: null, // Clear update time for new entry
        rowIndex: null, // Important: Nullify rowIndex to ensure it's treated as a new entry
        minimumStock: record.minimumStock, // NEW: Pass the minimum stock to the templated record
      );
      rowIndexToPass = null;
    }

    setState(() {
      _currentEditRecord = recordToPass;
      _editingRecordIndex = rowIndexToPass; // This will be null for new entry templates
      _selectedIndex = 1; // Navigate to the Daily Entry form
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
    String minStockStr = '', // NEW: minStockStr parameter
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
      minStockStr: minStockStr, // NEW: Pass minStockStr
    );

    if (!validationResult['success']) {
      _showSnackbar(validationResult['message'], isSuccess: false);
      return;
    }

    final Record recordToSubmit = validationResult['record'];
    bool success = false;
    String actionMessage = "";

    // Check if it's an update scenario based on _currentEditRecord and its rowIndex
    if (_currentEditRecord != null && _editingRecordIndex != null) { // Use _editingRecordIndex for the check
      success = await _sheetService.updateExistingRecord(recordToSubmit, _editingRecordIndex!);
      actionMessage = "Stock entry updated successfully!";
    } else {
      success = await _sheetService.appendRecord(recordToSubmit);
      actionMessage = "Stock entry added successfully!";
    }

    if (success) {
      _showSnackbar(actionMessage, isSuccess: true);
      _clearEditState();
      await _refreshAllData();
      setState(() {
        _selectedIndex = 0;
      });
    } else {
      _showSnackbar("Failed to process stock entry in Google Sheet.", isSuccess: false);
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
            onTapDashboardItem: _editEntry, // Now directly passes Record with rowIndex
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
            sheetService: _sheetService, // Pass the sheet service
            beanNameSuggestions: _beanNameSuggestions.toList(),
            inventoryNameSuggestions: _inventoryNameSuggestions.toList(),
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
  final void Function(Record record, int rowIndex) onTapDashboardItem;

  const DashboardContent({
    super.key,
    required this.dashboardData,
    required this.refreshDashboardData,
    required this.onTapDashboardItem,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  List<Record> _lowStockItems = [];
  List<Record> _normalStockItems = [];

  @override
  void initState() {
    super.initState();
    _categorizeStockItems();
  }

  @override
  void didUpdateWidget(covariant DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dashboardData != oldWidget.dashboardData) {
      _categorizeStockItems();
    }
  }

  void _categorizeStockItems() {
    _lowStockItems = [];
    _normalStockItems = [];
    for (var item in widget.dashboardData) {
      // Determine the current effective stock for comparison
      double currentStock = item.eveningStock;
      if (currentStock == 0) {
        currentStock = item.morningStock;
      }

      // Check for low stock condition
      if (item.minimumStock != null && item.minimumStock! > 0 && currentStock < item.minimumStock!) {
        _lowStockItems.add(item);
      } else {
        _normalStockItems.add(item);
      }
    }
    // Sort low stock items by how low they are (lowest ratio first)
    _lowStockItems.sort((a, b) {
      double stockA = a.eveningStock == 0.0 ? a.morningStock : a.eveningStock;
      double stockB = b.eveningStock == 0.0 ? b.morningStock : b.eveningStock;
      double ratioA = a.minimumStock != null && a.minimumStock! > 0 ? stockA / a.minimumStock! : double.infinity;
      double ratioB = b.minimumStock != null && b.minimumStock! > 0 ? stockB / b.minimumStock! : double.infinity;
      return ratioA.compareTo(ratioB);
    });
  }


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

          // --- Low Stock Alerts Section ---
          if (_lowStockItems.isNotEmpty) ...[
            Text(
              "🚨 Low Stock Alerts 🚨",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ..._lowStockItems.map((item) => _buildStockCard(context, item, isLowStock: true)).toList(),
            const Divider(height: 30, thickness: 2, color: Colors.redAccent),
            const SizedBox(height: 20),
          ],

          // --- All Other Stock Items Section ---
          if (widget.dashboardData.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "No stock data available. Add an entry!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else ..._normalStockItems.map((item) => _buildStockCard(context, item, isLowStock: false)).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStockCard(BuildContext context, Record item, {required bool isLowStock}) {
    String coffeeName;
    if (item.roastType == 'Single Origin' || item.roastType == 'Other Inventory') {
      coffeeName = "${item.roastType}: ${item.beanName}";
    } else {
      coffeeName = item.roastType;
    }
    String mainStockAmountDisplay = 'N/A';
    String grinderAmountDisplay = 'N/A';
    Color amountColorGrinder = Colors.green[600]!; // Default green
    Color amountColorMain = Colors.blueGrey[900]!;
    Color cardColor = Colors.blueGrey.shade50; // Default for normal stock items
    FontWeight mainStockFontWeight = FontWeight.bold; // Default to bold

    double overallStockAmount = item.eveningStock;
    if (overallStockAmount == 0) {
      overallStockAmount = item.morningStock;
    }
    mainStockAmountDisplay = formatQuantityDisplay(overallStockAmount, unit: 'g', roastType: item.roastType);

    final double? parsedMainStockAmount = double.tryParse(overallStockAmount.toString());


    // Logic for main stock color and card background
    if (item.minimumStock != null && item.minimumStock! > 0 && parsedMainStockAmount != null) {
      if (parsedMainStockAmount < item.minimumStock!) { // Highlight red if below min
        cardColor = Colors.red.shade300; // Stronger red for card background
        amountColorMain = Colors.red[900]!; // Darker red for text
        mainStockFontWeight = FontWeight.w900; // Extra bold
      } else if (parsedMainStockAmount <= (item.minimumStock! * 1.5) && item.roastType != 'Other Inventory') { // Example: within 150% of min stock
        cardColor = Colors.orange.shade200; // More noticeable orange for approaching low stock
        amountColorMain = Colors.orange[900]!; // Darker orange for text
      }
    }
    // If stock is exactly 0 and no specific minimum is set (or min is 0), still show grey
    if (parsedMainStockAmount == 0) {
      amountColorMain = Colors.grey;
    }


    if (item.roastType != 'Single Origin' && item.roastType != 'Other Inventory') {
      double grinderCalculation = 0.0;
      // Display morning in for morning shift, evening out for evening shift
      if (item.shift == 'Morning') {
        grinderCalculation = item.morningIn; // Show morning in
      } else if (item.shift == 'Evening') {
        grinderCalculation = item.eveningOut; // Show evening out
      }
      grinderAmountDisplay = formatQuantityDisplay(grinderCalculation, unit: 'g', roastType: item.roastType);
      final double? parsedGrinderAmount = double.tryParse(grinderAmountDisplay.replaceAll('g', '').replaceAll('N/A', '0'));

      // Grinder text color logic
      if (parsedGrinderAmount == 0) {
        amountColorGrinder = Colors.grey;
      } else if (parsedGrinderAmount != null && parsedGrinderAmount > 0 && parsedGrinderAmount <= 100) {
        amountColorGrinder = Colors.red[500]!; // Grinder-specific low threshold
      }

      // Override grinder color if overall stock is below minimum for the item
      if (item.minimumStock != null && item.minimumStock! > 0 && parsedMainStockAmount != null && parsedMainStockAmount < item.minimumStock!) {
        amountColorGrinder = Colors.red[900]!; // Make grinder text red if overall item is critically low
      }

    } else {
      grinderAmountDisplay = "N/A";
    }

    // Directly use item.rowIndex
    final int? rowIndexForEdit = item.rowIndex;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor, // Apply dynamic card color
      child: InkWell(
        onTap: () {
          if (rowIndexForEdit != null) {
            widget.onTapDashboardItem(item, rowIndexForEdit);
          } else {
            debugPrint("Error: Record missing rowIndex for dashboard item: ${item.roastType} - ${item.beanName}");
            // Optionally, show a snackbar to the user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not edit this item. Row index missing.'), backgroundColor: Colors.red),
            );
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
                        Row(
                          children: [
                            Text(
                              "Overall: ${mainStockAmountDisplay}",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: mainStockFontWeight, // Apply dynamic font weight
                                    color: amountColorMain, // Apply dynamic color
                                  ),
                            ),
                            if (item.minimumStock != null && item.minimumStock! > 0 && parsedMainStockAmount != null && parsedMainStockAmount < item.minimumStock!)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.warning, color: Colors.red[800], size: 24), // Warning icon
                              ),
                          ],
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
                            "Grinder: ${grinderAmountDisplay}",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: amountColorGrinder, // Apply dynamic color
                                ),
                          ),
                          Text("in grinder", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
              if (item.minimumStock != null && item.minimumStock! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Minimum: ${formatQuantityDisplay(item.minimumStock, unit: item.roastType.contains('Roast') || item.roastType == 'Single Origin' ? 'g' : 'units')}", // Display min stock
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey[500]),
                  ),
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
    String minStockStr, // NEW: minStockStr parameter
  }) submitEntry;
  final Record? currentEditRecord;
  final VoidCallback clearEditState;
  final VoidCallback goToDashboard;
  final GoogleSheetService sheetService; // New: Pass GoogleSheetService
  final List<String> beanNameSuggestions;
  final List<String> inventoryNameSuggestions;

  const DailyEntryContent({
    super.key,
    required this.submitEntry,
    this.currentEditRecord,
    required this.clearEditState,
    required this.goToDashboard,
    required this.sheetService, // New: Require GoogleSheetService
    required this.beanNameSuggestions,
    required this.inventoryNameSuggestions,
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
  final TextEditingController _soInventoryInController = TextEditingController();
  final TextEditingController _soInventoryOutController = TextEditingController();
  final TextEditingController _throwAwayController = TextEditingController(text: '0');
  final TextEditingController _testController = TextEditingController(text: '0');
  final TextEditingController _eventController = TextEditingController(text: '0');
  final TextEditingController _employeeShotController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController(); // NEW: Controller for minimum stock

  String _selectedShift = 'Morning';
  String? _selectedRoastType = 'Light Roast';
  bool _isSingleOrigin = false;
  bool _isOtherInventory = false;
  bool _isMorningShift = true;

  Record? _lastRecordForSelectedType; // New: Store the last record for display

  @override
  void initState() {
    super.initState();
    _initializeForm();
    // Listen for changes to beanNameController and RoastType dropdown to fetch last record
    _beanNameController.addListener(_fetchAndDisplayLastRecord);
    // Initial fetch since _selectedRoastType is set in _initializeForm
    _fetchAndDisplayLastRecord();
  }

  @override
  void didUpdateWidget(covariant DailyEntryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentEditRecord != oldWidget.currentEditRecord) {
      _initializeForm();
    }
    // Also re-fetch if sheetService itself somehow changes (unlikely for this app)
    if (widget.sheetService != oldWidget.sheetService) {
      _fetchAndDisplayLastRecord();
    }
  }

  // --- DailyEntryContentState (corrected _initializeForm) ---
  void _initializeForm() {
    if (widget.currentEditRecord != null) {
      // This condition checks if we're dealing with an edit or a templated new entry.
      // If widget.currentEditRecord!.rowIndex is NOT null, it means we're truly editing an existing record.
      if (widget.currentEditRecord!.rowIndex != null) {
        // This is a true "edit existing record" scenario (e.g., from History or a recent dashboard item)
        _dateController.text = widget.currentEditRecord!.date;
        _selectedShift = widget.currentEditRecord!.shift;
      } else {
        // This is the "template" scenario from the dashboard (where rowIndex was nulled out in _editEntry)
        // Use the pre-set date and shift from the templated record (current date, current/evening shift)
        _dateController.text = widget.currentEditRecord!.date;
        _selectedShift = widget.currentEditRecord!.shift;
      }

      // Populate common fields regardless of edit or new template
      _selectedRoastType = widget.currentEditRecord!.roastType;
      _beanNameController.text = widget.currentEditRecord!.beanName;
      _morningInController.text = widget.currentEditRecord!.morningIn == 0.0 ? '' : widget.currentEditRecord!.morningIn.toString();
      _addOnMorningController.text = widget.currentEditRecord!.addOnMorning == 0.0 ? '' : widget.currentEditRecord!.addOnMorning.toString();
      _addOnAfternoonController.text = widget.currentEditRecord!.addOnAfternoon == 0.0 ? '' : widget.currentEditRecord!.addOnAfternoon.toString();
      _eveningOutController.text = widget.currentEditRecord!.eveningOut == 0.0 ? '' : widget.currentEditRecord!.eveningOut.toString();

      // Conditional stock field population based on Roast Type and Shift
      if (widget.currentEditRecord!.roastType == 'Single Origin' || widget.currentEditRecord!.roastType == 'Other Inventory') {
        _soInventoryInController.text = widget.currentEditRecord!.morningStock == 0.0 ? '' : widget.currentEditRecord!.morningStock.toString();
        _soInventoryOutController.text = widget.currentEditRecord!.eveningStock == 0.0 ? '' : widget.currentEditRecord!.eveningStock.toString();
        _lmMorningStockController.clear();
        _lmEveningStockController.clear();
      } else {
        _lmMorningStockController.text = widget.currentEditRecord!.morningStock == 0.0 ? '' : widget.currentEditRecord!.morningStock.toString();
        _lmEveningStockController.text = widget.currentEditRecord!.eveningStock == 0.0 ? '' : widget.currentEditRecord!.eveningStock.toString();
        _soInventoryInController.clear();
        _soInventoryOutController.clear();
      }

      _throwAwayController.text = widget.currentEditRecord!.throwAway.toString();
      _testController.text = widget.currentEditRecord!.test.toString();
      _eventController.text = widget.currentEditRecord!.event.toString();
      _employeeShotController.text = widget.currentEditRecord!.employeeShot.toString();
      _notesController.text = widget.currentEditRecord!.notes;
      _minStockController.text = widget.currentEditRecord!.minimumStock == null ? '' : widget.currentEditRecord!.minimumStock!.toString(); // NEW: Populate minimum stock

    } else {
      // This is for a completely new, blank entry (e.g., directly clicking 'Add Entry' tab)
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentHour = DateTime.now().hour;
      _selectedShift = (currentHour < 12) ? 'Morning' : 'Evening';
      _selectedRoastType = 'Light Roast'; // Default for a new entry

      // Clear all fields for a fresh start
      _beanNameController.clear();
      _morningInController.clear();
      _addOnMorningController.clear();
      _addOnAfternoonController.clear();
      _eveningOutController.clear();
      _lmMorningStockController.clear();
      _lmEveningStockController.clear();
      _soInventoryInController.clear();
      _soInventoryOutController.clear();
      _throwAwayController.text = '0';
      _testController.text = '0';
      _eventController.text = '0';
      _employeeShotController.text = '0';
      _notesController.clear();
      _minStockController.clear(); // NEW: Clear minimum stock
    }
    _updateDependentFields();
  }

  void _updateDependentFields() {
    setState(() {
      _isSingleOrigin = _selectedRoastType == 'Single Origin';
      _isOtherInventory = _selectedRoastType == 'Other Inventory';
      _isMorningShift = _selectedShift == 'Morning';

      if (_isSingleOrigin || _isOtherInventory) {
        _morningInController.clear();
        _addOnMorningController.clear();
        _addOnAfternoonController.clear();
        _eveningOutController.clear();
        _lmMorningStockController.clear();
        _lmEveningStockController.clear();
        if (_isOtherInventory) {
          _throwAwayController.text = '0';
          _testController.text = '0';
          _eventController.text = '0';
          _employeeShotController.text = '0';
        }
      } else {
        _soInventoryInController.clear();
        _soInventoryOutController.clear();
      }

      if (_isMorningShift) {
        _addOnAfternoonController.clear();
        _eveningOutController.clear();
        _lmEveningStockController.clear();
        _soInventoryInController.clear();
      } else {
        _morningInController.clear();
        _addOnMorningController.clear();
        _lmMorningStockController.clear();
        _soInventoryInController.clear();
      }
    });
    _fetchAndDisplayLastRecord(); // Also fetch when roast type or shift changes
  }

  Future<void> _fetchAndDisplayLastRecord() async {
    // Only fetch if a roast type is selected
    if (_selectedRoastType == null || _selectedRoastType!.isEmpty) {
      setState(() {
        _lastRecordForSelectedType = null;
        _minStockController.clear(); // Clear minimum stock if no roast type
      });
      return;
    }

    final allRecordsWithIndex = await widget.sheetService.getAllRecordsWithIndex();
    final List<Record> allRecords = allRecordsWithIndex.map((map) => Record.fromMap(map)).toList();

    Record? latestRecord;
    DateTime? latestDate;
    DateTime? latestUpdateTime;

    for (var record in allRecords) {
      // Filter by roastType
      if (record.roastType != _selectedRoastType) continue;

      // Further filter by beanName if roastType is Single Origin or Other Inventory
      if ((_isSingleOrigin || _isOtherInventory) && record.beanName.trim().toLowerCase() != _beanNameController.text.trim().toLowerCase()) {
        continue;
      }

      final recordDate = DateTime.tryParse(record.date);
      final recordUpdateTime = DateTime.tryParse(record.updateTime ?? '');

      if (recordDate == null) continue;

      if (latestRecord == null || recordDate.isAfter(latestDate!)) {
        latestRecord = record;
        latestDate = recordDate;
        latestUpdateTime = recordUpdateTime;
      } else if (recordDate.isAtSameMomentAs(latestDate!)) {
        // If same date, use updateTime as the primary tie-breaker
        final currentUpdateTime = DateTime.tryParse(record.updateTime ?? ''); // Use record's update time
        final existingUpdateTime = DateTime.tryParse(latestRecord!.updateTime ?? ''); // Use latestRecord's update time

        // If both have update times, the newer update time wins
        if (currentUpdateTime != null && existingUpdateTime != null) {
          if (currentUpdateTime.isAfter(existingUpdateTime)) {
            latestRecord = record;
            latestDate = recordDate;
            latestUpdateTime = recordUpdateTime;
          }
          // If current is older or same, keep existing (no change needed)
        }
        // If only current has update time, current wins (it's a newer update)
        else if (currentUpdateTime != null && existingUpdateTime == null) {
          latestRecord = record;
          latestDate = recordDate;
          latestUpdateTime = recordUpdateTime;
        }
        // If only existing has update time, existing wins (it's a recorded update vs. a non-updated or unparseable current)
        // No 'else if' here, as the default will be to keep existing if none of the above conditions are met for 'item'
        else {
          // If neither has a valid update time (or both are null), fall back to shift and stock data
          // Prioritize Evening over Morning if shifts are different
          if (record.shift == 'Evening' && latestRecord!.shift == 'Morning') { // Corrected: Use latestRecord
            latestRecord = record;
            latestDate = recordDate;
            latestUpdateTime = recordUpdateTime;
          }
          // If both are Evening, or both Morning for same date, keep the one with more data
          else if (record.shift == latestRecord!.shift) { // Corrected: Use latestRecord
            if (record.eveningStock != 0 && latestRecord!.eveningStock == 0) { // Corrected: Use latestRecord
              latestRecord = record;
            } else if (record.morningStock != 0 && latestRecord!.morningStock == 0 && record.shift == 'Morning') { // Corrected: Use latestRecord
              latestRecord = record;
            } else if ((record.roastType == 'Single Origin' || record.roastType == 'Other Inventory')
                && record.beanName.isNotEmpty && latestRecord!.beanName.isEmpty) { // Corrected: Use latestRecord
              latestRecord = record;
            }
          }
        }
      }
    }

    setState(() {
      _lastRecordForSelectedType = latestRecord;
      // Populate minimum stock field from the latest record, but only if it's a new entry (not editing existing)
      // If currentEditRecord is null, it's a new entry, so auto-fill min stock
      // If currentEditRecord is not null but rowIndex is null, it's a template, also auto-fill min stock
      if (widget.currentEditRecord == null || widget.currentEditRecord!.rowIndex == null) {
        _minStockController.text = latestRecord?.minimumStock?.toString() ?? '';
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != DateTime.tryParse(_dateController.text)) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String _getDropdownLabel() {
    if (_isSingleOrigin) {
      return "Select Bean Type (Single Origin)";
    } else if (_isOtherInventory) {
      return "Select Item Type (Other Inventory)";
    } else {
      return "Select Roast Type (Light/Medium)";
    }
  }

  List<String> _getRoastTypeOptions() {
    return [
      'Light Roast',
      'Medium Roast',
      'Single Origin',
      'Other Inventory',
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    List<String>? suggestions,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suggestions != null && suggestions.isNotEmpty)
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return suggestions.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              controller.text = selection;
              // Trigger a fetch for last record when a suggestion is selected
              _fetchAndDisplayLastRecord();
              if (onSubmitted != null) onSubmitted();
            },
            fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, void Function() onFieldSubmitted) {
              if (fieldTextEditingController.text != controller.text) {
                fieldTextEditingController.text = controller.text;
              }
              return TextFormField(
                controller: fieldTextEditingController,
                focusNode: fieldFocusNode,
                decoration: InputDecoration(
                  labelText: labelText,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: keyboardType,
                enabled: enabled,
                onChanged: (value) {
                  controller.text = value;
                  // Debounce this call if performance is an issue for frequent typing
                  // For now, call directly to keep _lastRecordForSelectedType updated
                  _fetchAndDisplayLastRecord();
                },
                onFieldSubmitted: (_) {
                  if (onSubmitted != null) onSubmitted();
                },
              );
            },
          )
        else
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
            enabled: enabled,
            onFieldSubmitted: (_) {
              if (onSubmitted != null) onSubmitted();
            },
          ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
              readOnly: true,
              onTap: () => _selectDate(context),
            ),
            if (widget.currentEditRecord != null && widget.currentEditRecord!.updateTime != null && widget.currentEditRecord!.rowIndex != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text(
                  'Last Updated: ${widget.currentEditRecord!.updateTime}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              value: _selectedShift,
              decoration: const InputDecoration(
                labelText: 'Shift',
                border: OutlineInputBorder(),
              ),
              items: <String>['Morning', 'Evening'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedShift = newValue!;
                  _updateDependentFields();
                });
              },
            ),
            const SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              value: _selectedRoastType,
              decoration: InputDecoration(
                labelText: _getDropdownLabel(),
                border: const OutlineInputBorder(),
              ),
              items: _getRoastTypeOptions().map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRoastType = newValue!;
                  _updateDependentFields();
                });
              },
            ),
            const SizedBox(height: 16.0),
            if (_isSingleOrigin || _isOtherInventory)
              _buildTextField(
                controller: _beanNameController,
                labelText: _isOtherInventory ? 'Item Name (e.g., Cup, Filter)' : 'Bean Name (e.g., Ethiopia Yirgacheffe)',
                suggestions: _isOtherInventory ? widget.inventoryNameSuggestions : widget.beanNameSuggestions,
              ),

            // --- Last Recorded Values Section ---
            if (_lastRecordForSelectedType != null)
              Card(
                color: Colors.blue.withOpacity(0.05),
                margin: const EdgeInsets.symmetric(vertical: 20.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Recorded Values (${_lastRecordForSelectedType!.date} - ${_lastRecordForSelectedType!.shift})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                      ),
                      const SizedBox(height: 10),
                      if (_lastRecordForSelectedType!.updateTime != null)
                        Text(
                          'Updated: ${_lastRecordForSelectedType!.updateTime}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                        ),
                      const Divider(height: 20),
                      if (!_isSingleOrigin && !_isOtherInventory) ...[
                        _buildLastRecordDetail('Morning In (Grinder):', formatQuantityDisplay(_lastRecordForSelectedType!.morningIn)),
                        _buildLastRecordDetail('Add On Morning (Grinder):', formatQuantityDisplay(_lastRecordForSelectedType!.addOnMorning)),
                        _buildLastRecordDetail('Add On Afternoon (Grinder):', formatQuantityDisplay(_lastRecordForSelectedType!.addOnAfternoon)),
                        _buildLastRecordDetail('Evening Out (Grinder):', formatQuantityDisplay(_lastRecordForSelectedType!.eveningOut)),
                      ],
                      _buildLastRecordDetail('Morning Stock:', formatQuantityDisplay(_lastRecordForSelectedType!.morningStock, roastType: _selectedRoastType!)),
                      _buildLastRecordDetail('Evening Stock:', formatQuantityDisplay(_lastRecordForSelectedType!.eveningStock, roastType: _selectedRoastType!)),
                      if (!_isOtherInventory) ...[
                        _buildLastRecordDetail('Throw Away (Shots):', formatQuantityDisplay(_lastRecordForSelectedType!.throwAway, unit: 'shot')),
                        _buildLastRecordDetail('Test (Shots):', formatQuantityDisplay(_lastRecordForSelectedType!.test, unit: 'shot')),
                        _buildLastRecordDetail('Event (Shots):', formatQuantityDisplay(_lastRecordForSelectedType!.event, unit: 'shot')),
                        _buildLastRecordDetail('Employee (Shots):', formatQuantityDisplay(_lastRecordForSelectedType!.employeeShot, unit: 'shot')),
                      ],
                      if (_lastRecordForSelectedType!.minimumStock != null)
                        _buildLastRecordDetail('Minimum Stock:', formatQuantityDisplay(_lastRecordForSelectedType!.minimumStock, unit: _selectedRoastType!.contains('Roast') || _selectedRoastType! == 'Single Origin' ? 'g' : 'units')),
                      if (_lastRecordForSelectedType!.notes.isNotEmpty)
                        _buildLastRecordDetail('Notes:', _lastRecordForSelectedType!.notes),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16.0),
            // --- End Last Recorded Values Section ---

            if (!_isSingleOrigin && !_isOtherInventory) ...[
              if (_isMorningShift)
                _buildTextField(
                  controller: _morningInController,
                  labelText: 'Morning In (g) - Grinder',
                  keyboardType: TextInputType.number,
                ),
              _buildTextField(
                controller: _addOnMorningController,
                labelText: 'Add On Morning (g) - Grinder',
                keyboardType: TextInputType.number,
                enabled: _isMorningShift,
              ),
              _buildTextField(
                controller: _addOnAfternoonController,
                labelText: 'Add On Afternoon (g) - Grinder',
                keyboardType: TextInputType.number,
                enabled: !_isMorningShift,
              ),
              if (!_isMorningShift)
                _buildTextField(
                  controller: _eveningOutController,
                  labelText: 'Evening Out (g) - Grinder',
                  keyboardType: TextInputType.number,
                ),
            ],
            if (_isMorningShift)
              _buildTextField(
                controller: (_isSingleOrigin || _isOtherInventory) ? _soInventoryInController : _lmMorningStockController,
                labelText: (_isSingleOrigin || _isOtherInventory) ? '${_isOtherInventory ? 'Inventory' : 'Single Origin'} Total Stock (IN)' : 'Light/Medium Overall Stock (IN)',
                keyboardType: TextInputType.number,
              )
            else
              _buildTextField(
                controller: (_isSingleOrigin || _isOtherInventory) ? _soInventoryOutController : _lmEveningStockController,
                labelText: (_isSingleOrigin || _isOtherInventory) ? '${_isOtherInventory ? 'Inventory' : 'Single Origin'} Total Stock (OUT)' : 'Light/Medium Overall Stock (OUT)',
                keyboardType: TextInputType.number,
              ),

            if (!_isOtherInventory) ...[
              _buildTextField(
                controller: _throwAwayController,
                labelText: 'Throw Away (Shot)',
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _testController,
                labelText: 'Test (Shot)',
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _eventController,
                labelText: 'Event (Shot)',
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _employeeShotController,
                labelText: 'Employee (Shot)',
                keyboardType: TextInputType.number,
              ),
            ],
            // NEW: Minimum Stock Value input field
            _buildTextField(
              controller: _minStockController,
              labelText: 'Minimum Stock Value (${_selectedRoastType!.contains('Roast') || _selectedRoastType! == 'Single Origin' ? 'g' : 'units'})',
              keyboardType: TextInputType.number,
            ),
            _buildTextField(
              controller: _notesController,
              labelText: 'Notes/Comments',
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
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
                  soInStr: _soInventoryInController.text,
                  soOutStr: _soInventoryOutController.text,
                  throwAwayStr: _throwAwayController.text,
                  testStr: _testController.text,
                  eventStr: _eventController.text,
                  employeeShotStr: _employeeShotController.text,
                  notes: _notesController.text,
                  minStockStr: _minStockController.text, // NEW: Pass minStockStr
                );
              },
              child: Text(widget.currentEditRecord == null || widget.currentEditRecord!.rowIndex == null ? 'Add Stock Entry' : 'Submit Stock Entry'),
            ),
            if (widget.currentEditRecord != null && widget.currentEditRecord!.rowIndex != null) // Only show clear button if truly in edit mode
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: OutlinedButton(
                  onPressed: widget.clearEditState,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Clear Edit Form'),
                ),
              ),
            const SizedBox(height: 16.0),
            TextButton(
              onPressed: widget.goToDashboard,
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastRecordDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _beanNameController.removeListener(_fetchAndDisplayLastRecord); // Remove listener
    _beanNameController.dispose();
    _morningInController.dispose();
    _addOnMorningController.dispose();
    _addOnAfternoonController.dispose();
    _eveningOutController.dispose();
    _lmMorningStockController.dispose();
    _lmEveningStockController.dispose();
    _soInventoryInController.dispose();
    _soInventoryOutController.dispose();
    _throwAwayController.dispose();
    _testController.dispose();
    _eventController.dispose();
    _employeeShotController.dispose();
    _notesController.dispose();
    _minStockController.dispose(); // NEW: Dispose minimum stock controller
    super.dispose();
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
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredHistoryData = [];

  @override
  void initState() {
    super.initState();
    _filteredHistoryData = widget.historyData;
    _searchController.addListener(_filterHistory);
  }

  @override
  void didUpdateWidget(covariant HistoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historyData != oldWidget.historyData) {
      _filterHistory();
    }
  }

  void _filterHistory() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHistoryData = widget.historyData.where((recordMap) {
        final record = Record.fromMap(recordMap);
        return record.date.toLowerCase().contains(query) ||
               record.shift.toLowerCase().contains(query) ||
               record.roastType.toLowerCase().contains(query) ||
               record.beanName.toLowerCase().contains(query) ||
               record.notes.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterHistory);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.refreshHistoryData,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              "Stock History",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search History',
                hintText: 'Date, Shift, Roast Type, Bean Name, Notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_filteredHistoryData.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  widget.historyData.isEmpty ? "No history data available. Add an entry!" : "No matching records found for your search.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 40),
                    child: DataTable(
                      columnSpacing: 12.0,
                      dataRowMinHeight: 40.0,
                      dataRowMaxHeight: 60.0,
                      headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.withOpacity(0.1)),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Coffee/Item', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Morning In', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('AddOn Mor', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('AddOn Aft', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Evening Out', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Stock (g)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Throw', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Test', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Event', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Emp', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Update Time', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Min Stock', style: TextStyle(fontWeight: FontWeight.bold))), // NEW: Min Stock Column
                        DataColumn(label: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _filteredHistoryData.map((itemMap) {
                        final item = Record.fromMap(itemMap);
                        final rowIndex = itemMap['__rowIndex'] as int;

                        String coffeeItemName;
                        if (item.roastType == 'Single Origin' || item.roastType == 'Other Inventory') {
                          coffeeItemName = "${item.roastType}: ${item.beanName}";
                        } else {
                          coffeeItemName = item.roastType;
                        }

                        String morningInDisplay = 'N/A';
                        String addOnMorningDisplay = 'N/A';
                        String addOnAfternoonDisplay = 'N/A';
                        String eveningOutDisplay = 'N/A';

                        if (item.roastType != 'Single Origin' && item.roastType != 'Other Inventory') {
                          morningInDisplay = formatQuantityDisplay(item.morningIn);
                          addOnMorningDisplay = formatQuantityDisplay(item.addOnMorning);
                          addOnAfternoonDisplay = formatQuantityDisplay(item.addOnAfternoon);
                          eveningOutDisplay = formatQuantityDisplay(item.eveningOut);
                        }

                        String mainStockVal;
                        if (item.roastType == 'Single Origin' || item.roastType == 'Other Inventory') {
                          mainStockVal = formatQuantityDisplay(item.shift == 'Morning' ? item.morningStock : item.eveningStock, unit: 'g', roastType: item.roastType);
                        } else {
                          mainStockVal = formatQuantityDisplay(item.shift == 'Morning' ? item.morningStock : item.eveningStock, unit: 'g', roastType: item.roastType);
                        }

                        String throwAwayDisplay = formatQuantityDisplay(item.throwAway, unit: 'shot');
                        String testDisplay = formatQuantityDisplay(item.test, unit: 'shot');
                        String eventDisplay = formatQuantityDisplay(item.event, unit: 'shot');
                        String employeeShotDisplay = formatQuantityDisplay(item.employeeShot, unit: 'shot');
                        String minStockDisplay = item.minimumStock != null ? formatQuantityDisplay(item.minimumStock, unit: item.roastType.contains('Roast') || item.roastType == 'Single Origin' ? 'g' : 'units') : 'N/A'; // NEW: Min Stock Display

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
                            DataCell(Text(item.updateTime ?? 'N/A')),
                            DataCell(Text(minStockDisplay)), // NEW: Min Stock Value
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
              ),
          ],
        ),
      ),
    );
  }
}
