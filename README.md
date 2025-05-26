# Flutter Cafe Stock Tracker

## ☕ Keep Your Cafe Stock Perfectly Brewed!

This Flutter mobile and web application provides an intuitive and efficient way for cafes to track their daily coffee bean inventory, including various roast types and single origins, and even other essential inventory items like milk, snacks, and fruits. Powered by Google Sheets as its backend, this app offers real-time stock insights, streamlines daily entry, and maintains a comprehensive history of all stock movements.

---

## ✨ Features

* **Multi-Platform Access:** Seamlessly run the application on Android, iOS, Web, Windows, and macOS, providing flexibility for any cafe setup.
* **Intuitive Dashboard:** Get an instant overview of your current stock levels for all coffee roasts (Light, Medium, Single Origin) and general inventory items. Low stock warnings ensure you never run out!
* **Dynamic Daily Entry:**
    * Record morning and evening stock for different shifts.
    * Track grinder quantities (initial, add-ons, and remaining) for Light/Medium roasts.
    * Dedicated fields for Single Origin and **NEW: Other Inventory items (e.g., milk, snacks, apples)**.
    * **Smart Suggestions:** The "Bean Name" and "Item Name" fields offer real-time suggestions based on previous entries, speeding up data input and ensuring consistency.
    * Capture consumption metrics like 'Throw Away', 'Test', 'Event', and 'Employee Shots' (for coffee).
    * Add notes for detailed context.
* **Comprehensive History:** View all past entries in a sortable and searchable table, providing a clear audit trail of stock movements over time.
* **Edit Functionality:** Easily correct past entries from the history view, maintaining data accuracy.
* **Google Sheets Backend:** Utilizes a secure Google Service Account to interact directly with a Google Sheet, making data management simple, accessible, and familiar for non-technical users. No complex databases required!
* **Robust State Management:** Implemented with `StatefulWidget` and callbacks for clean and predictable data flow between screens.

---

## 🚀 Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install) installed and configured.
* [Android Studio](https://developer.android.com/studio) (for Android development, including SDK tools).
* A Google Cloud Project with the Google Sheets API enabled.
* A Google Service Account JSON key file.
    * **Crucial:** Ensure your Service Account has **Editor access** to your Google Sheet.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/YourGitHubUsername/flutter-cafe-stock-tracker.git](https://github.com/YourGitHubUsername/flutter-cafe-stock-tracker.git)
    cd flutter-cafe-stock-tracker
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Google Sheets API:**
    * Open your Google Service Account JSON key file.
    * Copy the values for `"private_key_id"`, `"private_key"`, and `"client_id"`.
    * Open `lib/main.dart` in your project.
    * Locate the `_serviceAccountJson` string.
    * **Carefully paste** your `private_key_id`, `private_key`, and `client_id` into the respective fields. Pay close attention to `private_key` as it's a multi-line string.
    * **Update `_spreadsheetId`**: Change `'1wlQHhw_vdMKA38hu_ydhnIFAVSCQuZV5Dh79eOrq9Vk'` to your actual Google Sheet ID.
    * **Verify `worksheetName`**: Ensure `'Sheet5'` matches the exact name of your worksheet tab.

4.  **Generate Launcher Icons (Optional but Recommended):**
    If you want a custom app icon, add your `app_icon.png` (preferably 1024x1024) to `assets/app_icon.png`.
    Then, add `flutter_launcher_icons` to `dev_dependencies` in `pubspec.yaml` and configure it:
    ```yaml
    # pubspec.yaml
    dev_dependencies:
      flutter_launcher_icons: "^0.13.1" # Check pub.dev for latest

    flutter_launcher_icons:
      android: "launcher_icon"
      ios: true
      image_path: "assets/app_icon.png"
      web:
        generate: true
        image_path: "assets/app_icon.png"
        background_color: "#ffffff"
        theme_color: "#ffffff"
      windows:
        generate: true
        image_path: "assets/app_icon.png"
      macos:
        generate: true
        image_path: "assets/app_icon.png"
    ```
    Then run:
    ```bash
    flutter pub get
    dart run flutter_launcher_icons
    ```

### Running the Application

* **For Web (fastest for development):**
    ```bash
    flutter run -d chrome
    ```
* **For Android (debug APK):**
    Connect an Android device or start an emulator, then run:
    ```bash
    flutter build apk --debug --split-per-abi
    ```
    You'll find the APKs in `build/app/outputs/flutter-apk/`.

---

## 🛠️ Technologies Used

* **Flutter:** The UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
* **Dart:** The programming language used by Flutter.
* **Google Sheets API (via `googleapis` & `googleapis_auth` packages):** For seamless integration with Google Sheets as a data backend.
* **`intl` package:** For date formatting.

---

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improvements or find a bug, please open an issue or submit a pull request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

---

## 📞 Contact

* **Kopkrit  Saikhiao** - https://www.linkedin.com/in/kopkritsaikhiao/ - kksaikheaw@gmail.com 
* Project Link: [https://github.com/tutalae/flutter-cafe-stock-tracker](https://github.com/YourGitHubUsername/flutter-cafe-stock-tracker)
