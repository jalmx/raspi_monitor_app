import 'dart:convert';

import 'package:raspi_monitor_app/model/Units.dart';

RawMonitorData getRawMonitorData(String jsonString) {
  final map = json.decode(jsonString) as Map<String, dynamic>;
  if (map['v'] == 1) {
    return RawMonitorData.fromJsonV1(map);
  } else {
    throw ("Unknown version: ${map['v']}");
  }
}

class RawMonitorData {
  final double cpuTemp; // C
  final double memUsed; // KB
  final double memTotal; // KB
  final double swapUsed; // KB
  final double swapTotal; // KB
  final double load1;
  final double load5;
  final double load15;
  final double cpuIdleTime;
  final double cpuTotalTime;
  final double cpuMhz; // Mhz
  final double cpuMaxMhz; // Mhz
  final double cpuMinMhz; // Mhz
  final double receivedBytes; // Byte
  final double sentBytes; // Byte
  final double diskRead; // KB
  final double diskWrite; // KB
  final double rootUsed; // KB
  final double rootTotal; // KB
  final int time; // millisecond

  RawMonitorData.fromJsonV1(Map<String, dynamic> json)
      : cpuTemp = json["cpu_temp"]?.toDouble(),
        memUsed = json["mem_used_kb"]?.toDouble(),
        memTotal = json["mem_total_kb"]?.toDouble(),
        swapUsed = json["swap_used_kb"]?.toDouble(),
        swapTotal = json["swap_total_kb"]?.toDouble(),
        load1 = json["load_1"]?.toDouble(),
        load5 = json["load_5"]?.toDouble(),
        load15 = json["load_15"]?.toDouble(),
        cpuIdleTime = json["cpu_idle_time"]?.toDouble(),
        cpuTotalTime = json["cpu_total_time"]?.toDouble(),
        cpuMhz = json["cpu_mhz"]?.toDouble(),
        cpuMaxMhz = json["cpu_max_mhz"]?.toDouble(),
        cpuMinMhz = json["cpu_min_mhz"]?.toDouble(),
        receivedBytes = json["received_bytes"]?.toDouble(),
        sentBytes = json["sent_bytes"]?.toDouble(),
        rootUsed = json["root_used_kb"]?.toDouble(),
        rootTotal = json["root_total_kb"]?.toDouble(),
        diskRead = json["total_disk_read_kb"]?.toDouble(),
        diskWrite = json["total_disk_read_kb"]?.toDouble(),
        time = json["time"];
}

class MonitorData {
  final RawMonitorData rawData;
  final double cpuUsage; // percentage
  final double networkUpSpeed; // Byte/s
  final double networkDownSpeed; // Byte/s
  final double diskWriteSpeed; // KB/s
  final double diskReadSpeed; // KB/s

  MonitorData._(
    this.rawData,
    this.cpuUsage,
    this.networkUpSpeed,
    this.networkDownSpeed,
    this.diskWriteSpeed,
    this.diskReadSpeed,
  );

  factory MonitorData(RawMonitorData oldRaw, RawMonitorData newRaw) {
    final interval = (newRaw.time - oldRaw.time) / 1000.0;
    final cpuIdleTime = newRaw.cpuIdleTime - oldRaw.cpuIdleTime;
    final cpuTotalTime = newRaw.cpuTotalTime - oldRaw.cpuTotalTime;
    final diskWritten = newRaw.diskWrite - oldRaw.diskWrite;
    final diskRead = newRaw.diskRead - oldRaw.diskRead;

    return MonitorData._(
      newRaw,
      1.0 - (cpuIdleTime / cpuTotalTime),
      (newRaw.sentBytes - oldRaw.sentBytes) / interval,
      (newRaw.receivedBytes - oldRaw.receivedBytes) / interval,
      diskWritten / interval,
      diskRead / interval,
    );
  }

  List<ChartItem> createChartItems() {
    final time = rawData.time;
    return [
      if (rawData.cpuTemp != null)
        ChartItem(
          name: 'Temperature',
          lines: [
            Line(
              'Temperature',
              [ChartDataPoint(time, Temperature(rawData.cpuTemp))],
            ),
          ],
        ),
      ChartItem(
        name: 'Memory',
        min: FileSize(0),
        max: FileSize.fromKB(rawData.memTotal),
        lines: [
          Line(
            'Memory',
            [ChartDataPoint(time, FileSize.fromKB(rawData.memUsed))],
          ),
        ],
      ),
      ChartItem(
        name: 'Swap',
        min: FileSize(0),
        max: FileSize.fromKB(rawData.swapTotal),
        lines: [
          Line(
            'Swap',
            [ChartDataPoint(time, FileSize.fromKB(rawData.swapUsed))],
          ),
        ],
      ),
      ChartItem(
        name: 'Load',
        min: RawNumber(0, ''),
        lines: [
          Line(
            'Load1',
            [ChartDataPoint(time, RawNumber(rawData.load1, ''))],
          ),
          Line(
            'Load5',
            [ChartDataPoint(time, RawNumber(rawData.load5, ''))],
          ),
          Line(
            'Load15',
            [ChartDataPoint(time, RawNumber(rawData.load15, ''))],
          ),
        ],
      ),
      ChartItem(
        name: 'CPU Usage',
        min: Percentage(0),
        max: Percentage(1),
        lines: [
          Line(
            'CPU Usage',
            [ChartDataPoint(time, Percentage(cpuUsage))],
          ),
        ],
      ),
      if (rawData.cpuMhz != null)
        ChartItem(
          name: 'CPU Frequency',
          min: Frequency(rawData.cpuMinMhz),
          max: Frequency(rawData.cpuMaxMhz),
          lines: [
            Line(
              'CPU Frequency',
              [ChartDataPoint(time, Frequency(rawData.cpuMhz))],
            ),
          ],
        ),
      ChartItem(
        name: 'Network',
        min: FileSizePerSecond(FileSize(0)),
        lines: [
          Line(
            'Upload',
            [ChartDataPoint(time, FileSizePerSecond(FileSize(networkUpSpeed)))],
          ),
          Line(
            'Download',
            [ChartDataPoint(time, FileSizePerSecond(FileSize(networkDownSpeed)))],
          ),
        ],
      ),
      ChartItem(
        name: 'Disk IO',
        min: FileSizePerSecond(FileSize(0)),
        lines: [
          Line(
            'Read',
            [ChartDataPoint(time, FileSizePerSecond(FileSize.fromKB(diskReadSpeed)))],
          ),
          Line(
            'Write',
            [ChartDataPoint(time, FileSizePerSecond(FileSize.fromKB(diskWriteSpeed)))],
          ),
        ],
      ),
      ChartItem(
        name: 'Disk Usage',
        min: FileSize(0),
        max: FileSize.fromKB(rawData.rootTotal),
        lines: [
          Line(
            'Disk Usage',
            [ChartDataPoint(time, FileSize.fromKB(rawData.rootUsed))],
          ),
        ],
      ),
    ];
  }

  List<ChartItem> appendToChartItems(List<ChartItem> chartItems) {
    final time = rawData.time;
    return chartItems.map((chartItem) {
      if (chartItem.name == 'Temperature') {
        return chartItem.append([ChartDataPoint(time, Temperature(rawData.cpuTemp))], time);
      } else if (chartItem.name == 'Memory') {
        return chartItem.append([ChartDataPoint(time, FileSize.fromKB(rawData.memUsed))], time);
      } else if (chartItem.name == 'Swap') {
        return chartItem.append([ChartDataPoint(time, FileSize.fromKB(rawData.swapUsed))], time);
      } else if (chartItem.name == 'Load') {
        return chartItem.append([
          ChartDataPoint(time, RawNumber(rawData.load1, '')),
          ChartDataPoint(time, RawNumber(rawData.load5, '')),
          ChartDataPoint(time, RawNumber(rawData.load15, '')),
        ], time);
      } else if (chartItem.name == 'CPU Usage') {
        return chartItem.append([ChartDataPoint(time, Percentage(cpuUsage))], time);
      } else if (chartItem.name == 'CPU Frequency') {
        return chartItem.append([ChartDataPoint(time, Frequency(rawData.cpuMhz))], time);
      } else if (chartItem.name == 'Network') {
        return chartItem.append([
          ChartDataPoint(time, FileSizePerSecond(FileSize(networkUpSpeed))),
          ChartDataPoint(time, FileSizePerSecond(FileSize(networkDownSpeed))),
        ], time);
      } else if (chartItem.name == 'Disk IO') {
        return chartItem.append([
          ChartDataPoint(time, FileSizePerSecond(FileSize.fromKB(diskReadSpeed))),
          ChartDataPoint(time, FileSizePerSecond(FileSize.fromKB(diskWriteSpeed))),
        ], time);
      } else if (chartItem.name == 'Disk Usage') {
        return chartItem.append([ChartDataPoint(time, FileSize.fromKB(rawData.rootUsed))], time);
      } else {
        throw ("Unknown chart item name: ${chartItem.name}");
      }
    }).toList();
  }
}

class ChartDataPoint {
  final int time; // millisecond
  final AutoScalableVector value;

  ChartDataPoint(this.time, this.value);
}

class Line {
  final String name;
  final List<ChartDataPoint> data;

  Line(this.name, this.data);

  Line append(ChartDataPoint dataPoint, int time) {
    final List<ChartDataPoint> newList = List.from(data)..add(dataPoint);
    while (newList.isNotEmpty) {
      if (newList[0].time < (time - 1000 * 60)) {
        newList.removeAt(0);
      } else {
        break;
      }
    }
    return Line(name, List.from(data)..add(dataPoint));
  }
}

class ChartItem {
  final String name;
  final AutoScalableVector max;
  final AutoScalableVector min;
  final List<Line> lines;

  ChartItem({this.name, this.min, this.max, this.lines});

  ChartItem append(List<ChartDataPoint> dataPoints, int time) {
    final newLines = <Line>[];
    for (var i = 0; i < lines.length; i++) {
      newLines.add(lines[i].append(dataPoints[i], time));
    }
    return ChartItem(
      name: name,
      max: max,
      min: min,
      lines: newLines,
    );
  }

  ChartDataPoint getMaxInView() {
    ChartDataPoint max;
    lines.forEach((line) {
      line.data.forEach((d) {
        if (max == null) {
          max = d;
        } else if (d.value.getRawValue() > max.value.getRawValue()) {
          max = d;
        }
      });
    });
    return max;
  }
}
