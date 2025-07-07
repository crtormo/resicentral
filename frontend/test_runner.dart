#!/usr/bin/env dart

import 'dart:io';

/// Test runner script for ResiCentral Flutter tests
void main(List<String> arguments) async {
  print('🧪 ResiCentral Frontend Test Runner');
  print('=' * 50);

  // Parse command line arguments
  final args = _parseArguments(arguments);
  
  if (args['help'] == true) {
    _printHelp();
    return;
  }

  try {
    // Run the appropriate test suite
    if (args['unit'] == true) {
      await _runUnitTests();
    } else if (args['widget'] == true) {
      await _runWidgetTests();
    } else if (args['integration'] == true) {
      await _runIntegrationTests();
    } else if (args['all'] == true) {
      await _runAllTests();
    } else {
      // Default: run unit and widget tests
      await _runUnitTests();
      await _runWidgetTests();
    }

    print('\n🎉 All tests completed successfully!');
  } catch (e) {
    print('\n💥 Test execution failed: $e');
    exit(1);
  }
}

Map<String, dynamic> _parseArguments(List<String> arguments) {
  final args = <String, dynamic>{
    'help': false,
    'unit': false,
    'widget': false,
    'integration': false,
    'all': false,
    'coverage': false,
    'verbose': false,
  };

  for (final arg in arguments) {
    switch (arg) {
      case '--help':
      case '-h':
        args['help'] = true;
        break;
      case '--unit':
        args['unit'] = true;
        break;
      case '--widget':
        args['widget'] = true;
        break;
      case '--integration':
        args['integration'] = true;
        break;
      case '--all':
        args['all'] = true;
        break;
      case '--coverage':
        args['coverage'] = true;
        break;
      case '--verbose':
      case '-v':
        args['verbose'] = true;
        break;
    }
  }

  return args;
}

void _printHelp() {
  print('''
Usage: dart test_runner.dart [options]

Options:
  --help, -h       Show this help message
  --unit           Run unit tests only
  --widget         Run widget tests only
  --integration    Run integration tests only
  --all            Run all tests
  --coverage       Generate coverage report
  --verbose, -v    Verbose output

Examples:
  dart test_runner.dart                # Run unit and widget tests
  dart test_runner.dart --all          # Run all tests
  dart test_runner.dart --unit         # Run unit tests only
  dart test_runner.dart --widget       # Run widget tests only
  dart test_runner.dart --integration  # Run integration tests only
  dart test_runner.dart --coverage     # Run with coverage
''');
}

Future<void> _runUnitTests() async {
  print('\n📋 Running Unit Tests...');
  print('-' * 30);

  final result = await Process.run(
    'flutter',
    ['test', 'test/unit_tests/', '--reporter', 'expanded'],
    workingDirectory: '.',
  );

  if (result.exitCode != 0) {
    print('❌ Unit tests failed');
    print(result.stdout);
    print(result.stderr);
    throw Exception('Unit tests failed');
  } else {
    print('✅ Unit tests passed');
    print(result.stdout);
  }
}

Future<void> _runWidgetTests() async {
  print('\n🎨 Running Widget Tests...');
  print('-' * 30);

  final result = await Process.run(
    'flutter',
    ['test', 'test/widget_tests/', '--reporter', 'expanded'],
    workingDirectory: '.',
  );

  if (result.exitCode != 0) {
    print('❌ Widget tests failed');
    print(result.stdout);
    print(result.stderr);
    throw Exception('Widget tests failed');
  } else {
    print('✅ Widget tests passed');
    print(result.stdout);
  }
}

Future<void> _runIntegrationTests() async {
  print('\n🔄 Running Integration Tests...');
  print('-' * 30);

  // Check if emulator/device is available
  final devicesResult = await Process.run('flutter', ['devices']);
  if (!devicesResult.stdout.toString().contains('device')) {
    print('⚠️  No devices available for integration tests');
    print('Please start an emulator or connect a device');
    return;
  }

  final result = await Process.run(
    'flutter',
    ['test', 'integration_test/', '--reporter', 'expanded'],
    workingDirectory: '.',
  );

  if (result.exitCode != 0) {
    print('❌ Integration tests failed');
    print(result.stdout);
    print(result.stderr);
    throw Exception('Integration tests failed');
  } else {
    print('✅ Integration tests passed');
    print(result.stdout);
  }
}

Future<void> _runAllTests() async {
  await _runUnitTests();
  await _runWidgetTests();
  await _runIntegrationTests();
}

Future<void> _runTestsWithCoverage() async {
  print('\n📊 Running Tests with Coverage...');
  print('-' * 40);

  final result = await Process.run(
    'flutter',
    ['test', '--coverage', '--reporter', 'expanded'],
    workingDirectory: '.',
  );

  if (result.exitCode != 0) {
    print('❌ Tests with coverage failed');
    print(result.stdout);
    print(result.stderr);
    throw Exception('Tests with coverage failed');
  } else {
    print('✅ Tests with coverage completed');
    print(result.stdout);
    
    // Generate HTML coverage report
    await _generateCoverageReport();
  }
}

Future<void> _generateCoverageReport() async {
  print('\n📈 Generating Coverage Report...');
  
  final result = await Process.run(
    'genhtml',
    ['coverage/lcov.info', '-o', 'coverage/html'],
    workingDirectory: '.',
  );

  if (result.exitCode == 0) {
    print('✅ Coverage report generated at coverage/html/index.html');
  } else {
    print('⚠️  Could not generate HTML coverage report');
    print('Install lcov: brew install lcov (macOS) or apt-get install lcov (Linux)');
  }
}