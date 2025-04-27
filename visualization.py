import argparse
import re
from datetime import datetime, time, timedelta
import os
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

def parse_date(date_str):
    today = datetime.today()
    if not date_str:
        return today.year, today.month, today.day
    
    parts = re.split(r'\D+', date_str.strip())
    parts = [p for p in parts if p]
    
    if len(parts) == 3:
        year, month, day = map(int, parts)
    elif len(parts) == 2:
        year, month, day = today.year, int(parts[0]), int(parts[1])
    elif len(parts) == 1:
        year, month, day = today.year, today.month, int(parts[0])
    else:
        raise ValueError("Invalid date format")
    
    return year, month, day

def parse_file(filepath):
    data = {}
    attributes = {}
    
    time_pattern = re.compile(r'^#\s*(\d{1,2}):(\d{1,2}):(\d{1,2})')
    attribute_pattern = re.compile(r'.*?\b([A-Z]{2,})\b.*?[:：]\s*(\d+)', re.IGNORECASE)
    bold_pattern = re.compile(r'\*\*(.*?)\*\*')
    
    current_time = None
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            time_match = time_pattern.match(line)
            if time_match:
                h, m, s = map(int, time_match.groups())
                current_time = time(h, m, s)
                data[current_time] = {}
                continue
            
            if current_time is None:
                continue
            
            attr_match = attribute_pattern.match(line)
            if attr_match:
                attr_name = attr_match.group(1).upper()
                attr_value = int(attr_match.group(2))
                data[current_time][attr_name] = attr_value
                
                # Check bold
                is_bold = bool(bold_pattern.search(line))
                if attr_name not in attributes or attributes[attr_name] is False:
                    attributes[attr_name] = is_bold
    
    return data, attributes

def interpolate_data(data, attributes, year, month, day):
    base_date = datetime(year, month, day)
    interpolated = {}
    
    full_index = pd.date_range(
        start=base_date,
        end=base_date.replace(hour=23, minute=59),
        freq='min'
    )
    
    for attr in attributes:
        points = []
        for t in sorted(data.keys()):
            if attr in data[t]:
                dt = datetime.combine(base_date, t)
                points.append((dt, data[t][attr]))
        
        if not points:
            continue
        
        times, values = zip(*sorted(points))
        series = pd.Series(values, index=times)
        
        series = series.resample('min').first()
        
        try:
            series = series.interpolate(method='time')
            series.ffill(inplace=True)
            series.bfill(inplace=True)
        except ValueError:
            series = series.ffill().bfill()
        
        full_series = series.reindex(full_index, method='nearest')
        
        interpolated[attr] = full_series
    
    return interpolated

def plot_data(interpolated, attributes, selected_attrs):
    plt.figure(figsize=(14, 7))
    for attr in selected_attrs:
        if attr not in interpolated:
            continue
        series = interpolated[attr]
        plt.plot(series.index, series.values, label=attr, linewidth=2)
    
    plt.xlabel('Time', fontsize=12)
    plt.ylabel('Value', fontsize=12)
    plt.title('Attribute Trends', fontsize=14)
    plt.legend()
    
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    plt.gca().xaxis.set_major_locator(mdates.HourLocator(interval=2))
    plt.gcf().autofmt_xdate()
    
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    
    # Add annotations
    for attr in selected_attrs:
        if attr not in interpolated:
            continue
        series = interpolated[attr]
        last_value = series.values[-1]
        last_time = series.index[-1]
        plt.text(last_time, last_value, f'{attr}: {last_value}', ha='right', va='bottom')
    
    plt.show()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--date', help='Specify date (YYYY-MM-DD, MM-DD, DD)', default='')
    parser.add_argument('-f', '--fields', nargs='+', help='Attributes to visualize', default=[])
    parser.add_argument('-a', '--all', action='store_true', help='Show all attributes')
    args = parser.parse_args()
    
    year, month, day = parse_date(args.date)
    filepath = f"./{year}/{month:02d}/{day:02d}.md"
    
    if not os.path.exists(filepath):
        print(f"File {filepath} not found")
        return
    
    data, attributes = parse_file(filepath)

    if not data:
        print("No valid data found in file")
        return
    
    # Determine selected attributes
    selected_attrs = args.fields
    if not selected_attrs:
        selected_attrs = [attr for attr, bold in attributes.items() if bold]

    if args.all:
        selected_attrs = list(attributes.keys())
    
    if not selected_attrs:
        print("No attributes selected for visualization")
        return
    
    # Interpolate data
    interpolated = interpolate_data(data, attributes, year, month, day)

    # Plot
    plot_data(interpolated, attributes, selected_attrs)

if __name__ == "__main__":
    main()