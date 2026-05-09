import re
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple

class LogAnalyzer:
    def __init__(self, time_window_minutes: int = 30):
        self.time_window = timedelta(minutes=time_window_minutes)
        self.error_patterns = [
            r"ERROR",
            r"CRITICAL",
            r"Exception",
            r"Traceback",
            r"Failed",
            r"Timeout",
            r"Connection refused",
            r"Out of memory"
        ]
        self.events = []
        self.error_counts = defaultdict(int)
    
    def read_log_files(self, log_dir: str) -> List[str]:
        """Read all log files from directory"""
        log_files = []
        path = Path(log_dir)
        for log_file in path.glob("*.log"):
            with open(log_file, 'r') as f:
                log_files.extend(f.readlines())
        return log_files
    
    def extract_timestamp(self, line: str) -> datetime:
        """Extract timestamp from log line"""
        timestamp_pattern = r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
        match = re.search(timestamp_pattern, line)
        if match:
            return datetime.strptime(match.group(), "%Y-%m-%d %H:%M:%S")
        return None
    
    def identify_error_patterns(self, lines: List[str]) -> Dict[str, List[Tuple[datetime, str]]]:
        """Identify error patterns and extract timestamps"""
        errors_by_type = defaultdict(list)
        
        for line in lines:
            timestamp = self.extract_timestamp(line)
            for pattern in self.error_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    errors_by_type[pattern].append((timestamp, line.strip()))
                    self.error_counts[pattern] += 1
                    break
        
        return errors_by_type
    
    def correlate_errors(self, errors_by_type: Dict[str, List[Tuple[datetime, str]]]) -> List[Tuple[datetime, str, int]]:
        """Correlate errors within time window"""
        timeline = []
        
        for error_type, occurrences in errors_by_type.items():
            if not occurrences:
                continue
            
            sorted_occurrences = sorted(occurrences, key=lambda x: x[0])
            
            for timestamp, line in sorted_occurrences:
                if timestamp:
                    count_in_window = sum(
                        1 for ts, _ in sorted_occurrences
                        if ts and abs((ts - timestamp).total_seconds()) <= self.time_window.total_seconds()
                    )
                    timeline.append((timestamp, error_type, count_in_window))
                    self.events.append((timestamp, line, error_type))
        
        return sorted(timeline, key=lambda x: x[0])
    
    def find_root_cause(self, timeline: List[Tuple[datetime, str, int]]) -> Tuple[str, int, datetime]:
        """Flag most likely root cause based on clustering"""
        if not timeline:
            return None, 0, None
        
        max_cluster_size = 0
        root_cause_type = None
        root_cause_time = None
        
        for error_type, count in self.error_counts.items():
            cluster_size = count
            if cluster_size > max_cluster_size:
                max_cluster_size = cluster_size
                root_cause_type = error_type
                
                # Find first occurrence of this error type
                for ts, etype, _ in timeline:
                    if etype == error_type:
                        root_cause_time = ts
                        break
        
        return root_cause_type, max_cluster_size, root_cause_time
    
    def generate_report(self, log_dir: str) -> None:
        """Generate incident response report"""
        print("=" * 60)
        print("LOG ANALYSIS REPORT")
        print("=" * 60)
        
        # Read logs
        lines = self.read_log_files(log_dir)
        if not lines:
            print("No log files found.")
            return
        
        # Identify errors
        errors_by_type = self.identify_error_patterns(lines)
        
        # Correlate errors
        timeline = self.correlate_errors(errors_by_type)
        
        # Print error counts
        print("\n[ERROR COUNTS]")
        for error_type, count in sorted(self.error_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"  {error_type}: {count}")
        
        # Print timeline
        print("\n[EVENT TIMELINE]")
        for timestamp, error_type, cluster_count in timeline:
            if timestamp:
                print(f"  {timestamp.isoformat()} | {error_type} (cluster: {cluster_count})")
        
        # Print root cause
        root_cause, count, first_time = self.find_root_cause(timeline)
        print("\n[ROOT CAUSE ANALYSIS]")
        if root_cause:
            print(f"  Most likely root cause: {root_cause}")
            print(f"  Occurrences: {count}")
            print(f"  First occurrence: {first_time.isoformat() if first_time else 'Unknown'}")
        else:
            print("  No root cause identified.")
        
        print("\n" + "=" * 60)


if __name__ == "__main__":
    import sys
    
    # Example usage
    log_directory = sys.argv[1] if len(sys.argv) > 1 else "./logs"
    
    analyzer = LogAnalyzer(time_window_minutes=30)
    analyzer.generate_report(log_directory)
