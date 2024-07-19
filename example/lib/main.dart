import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_merger/pdf_merger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<PlatformFile>? files;
  List<String>? filesPath;
  String? singleFile;

  @override
  void initState() {
    super.initState();
    clear();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Merger'),
        ),
        body: Center(
          child: Container(
            margin: EdgeInsets.all(25),
            child: Column(
              children: [
                _buildButton("Choose File", multipleFilePicker),
                SizedBox(height: 10),
                _buildButton("Merge Multiple PDF", () => callMethod(1)),
                SizedBox(height: 10),
                _buildButton("Create PDF From Multiple Image", () => callMethod(2)),
                SizedBox(height: 10),
                _buildButton("Create Image From PDF", () => singleFilePicker(1)),
                SizedBox(height: 10),
                _buildButton("Get File Size", () => singleFilePicker(2)),
                SizedBox(height: 10),
                _buildButton("Clear", clear),
                SizedBox(height: 10),
                _buildButton("Build Info", buildInfo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return TextButton(
      style: ButtonStyle(
        overlayColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
          if (states.contains(MaterialState.focused)) return Colors.red;
          if (states.contains(MaterialState.hovered)) return Colors.green;
          if (states.contains(MaterialState.pressed)) return Colors.blue;
          return Colors.red;
        }),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14.0),
      ),
      onPressed: onPressed,
    );
  }

  void clear() {
    setState(() {
      files = [];
      filesPath = [];
      singleFile = "";
    });
  }

  Future<void> multipleFilePicker() async {
    bool isGranted = await checkPermission();
    if (isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
        if (result != null) {
          setState(() {
            files = result.files;
            filesPath = result.files.map((file) => file.path ?? '').toList();
          });
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  Future<void> singleFilePicker(int type) async {
    bool isGranted = await checkPermission();
    if (isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);
        if (result != null) {
          setState(() {
            singleFile = result.files.single.path;
          });
          switch (type) {
            case 1:
              callMethod(3);
              break;
            case 2:
              callMethod(4);
              break;
          }
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  Future<void> callMethod(int type) async {
    String dirPath;
    switch (type) {
      case 1:
      case 2:
        dirPath = await getFilePath("TestPDFMerger");
        if (type == 1) {
          await mergeMultiplePDF(dirPath);
        } else if (type == 2) {
          await createPDFWithMultipleImage(dirPath);
        }
        break;
      case 3:
        dirPath = await getFilePathImage("TestPDFMerger");
        await createImageFromPDF(dirPath);
        break;
      case 4:
        await sizeForLocalFilePath();
        break;
    }
  }

  Future<void> mergeMultiplePDF(String outputDirPath) async {
    try {
      MergeMultiplePDFResponse response = await PdfMerger.mergeMultiplePDF(
        paths: filesPath!,
        outputDirPath: outputDirPath,
      );
   //   Get.snackbar("Info", response.message);
      if (response.status == "success") {
        OpenFile.open(response.response);
      }
    } on PlatformException catch (e) {
      print('Error: $e');
    }
  }

  Future<void> createPDFWithMultipleImage(String outputDirPath) async {
    try {
      CreatePDFFromMultipleImageResponse response = await PdfMerger.createPDFFromMultipleImage(
        paths: filesPath!,
        outputDirPath: outputDirPath,
      );
    //  Get.snackbar("Info", response.message);
      if (response.status == "success") {
        OpenFile.open(response.response);
      }
    } on PlatformException catch (e) {
      print('Error: $e');
    }
  }

  Future<void> createImageFromPDF(String outputDirPath) async {
    try {
      CreateImageFromPDFResponse response = await PdfMerger.createImageFromPDF(
        path: singleFile!,
        outputDirPath: outputDirPath,
        createOneImage: true,
      );
     //Get.snackbar("Info", response.status);
      if (response.status == "success") {
        OpenFile.open(response.response![0]);
      }
    } on PlatformException catch (e) {
      print('Error: $e');
    }
  }

  Future<void> sizeForLocalFilePath() async {
    try {
      SizeFormPathResponse response = await PdfMerger.sizeFormPath(path: singleFile!);
      if (response.status == "success") {
       // Get.snackbar("Info", response.response);
      }
    } on PlatformException catch (e) {
      print('Error: $e');
    }
  }

  Future<void> buildInfo() async {
    try {
      BuildInfoResponse response = await PdfMerger.buildInfo();
      Get.snackbar(
        "Info",
        "App Name : ${response.appName}\n" +
            "Build Number : ${response.buildDate}\n" +
            "Build Number with Time : ${response.buildDateWithTime}\n" +
            "Package Name : ${response.packageName}\n" +
            "Version Number : ${response.versionNumber}\n" +
            "Build Number : ${response.buildNumber}",
      );
    } on PlatformException catch (e) {
      print('Error: $e');
    }
  }

  Future<bool> checkPermission() async {
    var status = await Permission.storage.status;
    if (status.isDenied) {
      await Permission.storage.request();
    }
    return Permission.storage.isGranted;
  }

  Future<String> getFilePath(String fileStartName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/$fileStartName.pdf';
  }

  Future<String> getFilePathImage(String fileStartName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/$fileStartName.png';
  }
}
