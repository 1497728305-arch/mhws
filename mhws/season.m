%% 基于OISST海温数据的海洋热浪季节变化与统计分析(1982-2024)
% 分析区域: 30-60°N, 110-180°E
% 时间范围: 1982-2024年
% 重点分析: 2015-2024年海洋热浪的显著变化


%% 1. 设置环境
clear; clc; close all;
set(0, 'DefaultAxesFontSize', 12, 'DefaultTextFontSize', 14);

% 设置工作目录
data_dir = 'D:\dlb\m_mhw1.0-master\m_mhw1.0-master\data\global';     % OISST数据存储目录
result_dir = 'D:\dlb\m_mhw1.0-master\m_mhw1.0-master\data\Results\'; % 结果输出目录
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

% 定义目标区域
target_lat = [30, 60];    % 北纬30-60度
target_lon = [110, 180];  % 东经110-180度

% 定义时间范围
full_years = 1982:2024;   % 完整分析期
analysis_years = 2015:2024; % 重点分析期
baseline_years = 1982:2011; % 气候基准期
historical_years = 1982:2014; % 历史对比期

% 季节定义
seasons = struct(...
    'Winter', [12, 1, 2], ...  % 冬季: 12月,1月,2月
    'Spring', [3, 4, 5], ...   % 春季: 3月,4月,5月
    'Summer', [6, 7, 8], ...   % 夏季: 6月,7月,8月
    'Autumn', [9, 10, 11]);    % 秋季: 9月,10月,11月

season_names = fieldnames(seasons);

% 添加必要的工具箱路径
addpath(genpath('D:\MATLAB_Toolbox\'));
if ~exist('m_proj', 'file')
    error('请安装M_Map工具箱: https://www.eoas.ubc.ca/~rich/map.html');
end

%% 2. 加载OISST数据
fprintf('加载OISST海温数据...\n');

% 获取NC文件列表
nc_files = dir(fullfile(data_dir, '*.nc'));
if isempty(nc_files)
    error('未找到NC文件，请检查数据目录: %s', data_dir);
end

% 读取第一个文件获取维度信息
first_file = fullfile(data_dir, nc_files(1).name);
lon = ncread(first_file, 'lon');
lat = ncread(first_file, 'lat');
time = ncread(first_file, 'time'); % 通常是从1800年1月1日以来的天数

% 确定目标区域索引
lat_idx = find(lat >= target_lat(1) & lat <= target_lat(2));
lon_idx = find(lon >= target_lon(1) & lon <= target_lon(2));
region_lat = lat(lat_idx);
region_lon = lon(lon_idx);

% 初始化存储数组
sst_data = [];
all_dates = [];

% 循环读取所有文件
for i = 1:length(nc_files)
    file_path = fullfile(data_dir, nc_files(i).name);
    
    % 读取时间信息
    time = ncread(file_path, 'time');
    time_units = ncreadatt(file_path, 'time', 'units');
    
    % 转换时间为日期格式
    if contains(time_units, 'days since')
        ref_date = extractBetween(time_units, 'days since ', ' ');
        ref_date = datetime(ref_date{1});
        dates = ref_date + days(time);
    else
        % 默认处理：假设时间是从1800年1月1日以来的天数
        dates = datetime(1800,1,1) + days(time);
    end
    
    % 读取SST数据（仅目标区域）
    sst = ncread(file_path, 'sst', [min(lon_idx), min(lat_idx), 1], ...
                 [length(lon_idx), length(lat_idx), length(time)], [1, 1, 1]);
    
    % 转换为lat×lon×time格式
    sst = permute(sst, [2, 1, 3]);
    
    % 处理缺失值（通常为-9.96921e+36）
    sst(sst < -10) = NaN;
    
    % 存储数据
    sst_data = cat(3, sst_data, sst);
    all_dates = [all_dates; dates(:)];
    
    fprintf('已加载: %s (%s 到 %s)\n', nc_files(i).name, ...
        datestr(min(dates)), datestr(max(dates)));
end

% 按时间排序
[all_dates, sort_idx] = sort(all_dates);
sst_data = sst_data(:, :, sort_idx);

fprintf('数据加载完成. 区域: %.1f-%.1f°N, %.1f-%.1f°E, 时间: %s 到 %s\n', ...
    target_lat(1), target_lat(2), target_lon(1), target_lon(2), ...
    datestr(min(all_dates)), datestr(max(all_dates)));

%% 3. 计算气候基准和阈值
fprintf('计算气候基准和阈值...\n');

% 提取年份和日期信息
years = year(all_dates);
months = month(all_dates);
doy = day(all_dates, 'dayofyear'); % 年积日

% 创建基线期掩膜
baseline_mask = ismember(years, baseline_years);

% 初始化阈值矩阵
threshold = nan(size(sst_data, 1), size(sst_data, 2), 366);

% 计算每天的气候第90百分位数（使用基线期数据）
for day_of_year = 1:366
    % 查找所有年份中的当前DOY（考虑闰年）
    doy_mask = (doy == day_of_year) | (doy == day_of_year & ~leapyear(years));
    doy_mask = doy_mask & baseline_mask;
    
    if sum(doy_mask) > 0
        % 提取所有基线期中该DOY的数据
        sst_doy = sst_data(:, :, doy_mask);
        
        % 计算第90百分位数
        threshold(:, :, day_of_year) = prctile(sst_doy, 90, 3, 'Method', 'approximate');
    end
end

% 对于缺失值，使用前后几天的平均值进行填补
for i = 1:size(threshold, 1)
    for j = 1:size(threshold, 2)
        nan_idx = isnan(squeeze(threshold(i, j, :)));
        if any(nan_idx)
            valid_data = squeeze(threshold(i, j, ~nan_idx));
            threshold(i, j, nan_idx) = mean(valid_data, 'omitnan');
        end
    end
end

%% 4. 识别海洋热浪事件
fprintf('识别海洋热浪事件...\n');

% 初始化热浪指标
hw_metrics = struct(...
    'duration', nan(size(sst_data, 1), size(sst_data, 2), length(full_years)), ...
    'intensity', nan(size(sst_data, 1), size(sst_data, 2), length(full_years)), ...
    'cumulative_intensity', nan(size(sst_data, 1), size(sst_data, 2), length(full_years)), ...
    'frequency', zeros(size(sst_data, 1), size(sst_data, 2), length(full_years)));

% 循环处理每一年
for y = 1:length(full_years)
    current_year = full_years(y);
    year_mask = (years == current_year);
    
    if sum(year_mask) == 0
        continue; % 跳过没有数据的年份
    end
    
    % 提取当前年份数据
    sst_year = sst_data(:, :, year_mask);
    dates_year = all_dates(year_mask);
    doy_year = doy(year_mask);
    
    % 获取当前年份中每天的阈值
    threshold_year = threshold(:, :, doy_year);
    
    % 计算温度异常
    sst_anomaly = sst_year - threshold_year;
    
    % 检测超过阈值的日期
    exceed_threshold = sst_anomaly > 0;
    
    % 识别热浪事件（连续超过阈值至少5天）
    for i = 1:size(exceed_threshold, 1)
        for j = 1:size(exceed_threshold, 2)
            % 跳过陆地/缺失网格点
            if all(isnan(squeeze(sst_year(i, j, :))))
                continue;
            end
            
            % 获取当前位置的时间序列
            ts = squeeze(exceed_threshold(i, j, :));
            
            % 识别连续事件
            events = identify_heatwave_events(ts);
            
            % 存储结果
            if ~isempty(events)
                % 事件频率
                hw_metrics.frequency(i, j, y) = length(events);
                
                % 总持续时间和平均强度
                total_duration = 0;
                all_intensities = [];
                
                for e = 1:length(events)
                    event_days = events(e).start:events(e).end;
                    total_duration = total_duration + events(e).duration;
                    
                    % 计算事件强度
                    event_intensity = sst_anomaly(i, j, event_days);
                    all_intensities = [all_intensities; event_intensity(:)];
                end
                
                hw_metrics.duration(i, j, y) = total_duration;
                hw_metrics.intensity(i, j, y) = mean(all_intensities, 'omitnan');
                hw_metrics.cumulative_intensity(i, j, y) = sum(all_intensities, 'omitnan');
            end
        end
    end
    
    fprintf('已完成年份: %d\n', current_year);
end

%% 5. 季节变化分析（稳健版）
fprintf('进行季节变化分析（稳健版）...\n');

% 提取月份和年份信息
all_months = month(all_dates);
all_years = year(all_dates);

% 定义季节（与之前一致）
seasons = struct(...
    'Winter', [12, 1, 2], ...
    'Spring', [3, 4, 5], ...
    'Summer', [6, 7, 8], ...
    'Autumn', [9, 10, 11]);
season_names = fieldnames(seasons);

% 初始化季节热浪指标（lat, lon, year）
[nlat, nlon] = size(sst_data, [1,2]);
n_year = length(full_years);
for s = 1:length(season_names)
    season = season_names{s};
    seasonal_metrics.(season) = struct(...
        'frequency', zeros(nlat, nlon, n_year), ...
        'duration', zeros(nlat, nlon, n_year), ...
        'intensity', zeros(nlat, nlon, n_year));
end

% 为每个网格点、每年、每个季节聚合热浪指标
% 注意：我们需要逐日数据，但 hw_metrics 只存储了每年的总量/平均，无法拆分季节。
% 因此，我们必须重新使用逐日的 exceed_threshold 和 sst_anomaly 来计算季节指标。
% 由于原代码中已经计算了 exceed_threshold 和 sst_anomaly，我们可以利用它们。

% 重新整理逐日数据：为了节省内存，我们可以在每年循环中重新计算 exceed_threshold 和 sst_anomaly。
% 但这里我们直接利用已经读入的 sst_data 和 threshold，重新计算每日 exceed 和 anomaly。

fprintf('重新计算逐日热浪掩码和强度（用于季节聚合）...\n');

% 预分配逐日热浪掩码和强度（如果内存不足，可以逐季节累加）
% 这里采用逐年份、逐季节累加的方法，避免存储全部时间序列。

% 循环每年
for y = 1:n_year
    current_year = full_years(y);
    year_mask = (all_years == current_year);
    if sum(year_mask) == 0
        continue;
    end
    
    % 提取当年数据
    sst_year = sst_data(:, :, year_mask);
    doy_year = doy(year_mask);
    months_year = all_months(year_mask);
    dates_year = all_dates(year_mask);
    
    % 获取当年每天的阈值
    threshold_year = threshold(:, :, doy_year);
    
    % 计算温度异常和超过阈值的掩码
    sst_anomaly_year = sst_year - threshold_year;
    exceed_year = sst_anomaly_year > 0;
    
    % 初始化当年每个季节的累加器（网格点级别）
    season_freq = zeros(nlat, nlon, 4);
    season_dur = zeros(nlat, nlon, 4);
    season_intensity_sum = zeros(nlat, nlon, 4);
    season_intensity_cnt = zeros(nlat, nlon, 4);
    
    % 对每个网格点识别热浪事件（连续超过阈值至少5天）
    for i = 1:nlat
        for j = 1:nlon
            if all(isnan(squeeze(sst_year(i,j,:))))
                continue;
            end
            ts = squeeze(exceed_year(i,j,:));
            events = identify_heatwave_events(ts);
            if isempty(events)
                continue;
            end
            
            % 对每个事件，确定其所属季节（基于事件开始日期的月份）
            for e = 1:length(events)
                start_idx = events(e).start;
                end_idx = events(e).end;
                % 使用事件中间日或起始日判断季节（这里用起始日）
                event_date = dates_year(start_idx);
                event_month = month(event_date);
                % 确定季节索引
                if ismember(event_month, [12,1,2])
                    s_idx = 1; % Winter
                elseif ismember(event_month, [3,4,5])
                    s_idx = 2; % Spring
                elseif ismember(event_month, [6,7,8])
                    s_idx = 3; % Summer
                elseif ismember(event_month, [9,10,11])
                    s_idx = 4; % Autumn
                else
                    continue;
                end
                
                % 累加频率
                season_freq(i,j,s_idx) = season_freq(i,j,s_idx) + 1;
                % 累加持续时间
                season_dur(i,j,s_idx) = season_dur(i,j,s_idx) + events(e).duration;
                % 累加强度（事件期间的平均异常）
                event_intensity = mean(sst_anomaly_year(i,j,start_idx:end_idx), 'omitnan');
                if ~isnan(event_intensity)
                    season_intensity_sum(i,j,s_idx) = season_intensity_sum(i,j,s_idx) + event_intensity;
                    season_intensity_cnt(i,j,s_idx) = season_intensity_cnt(i,j,s_idx) + 1;
                end
            end
        end
    end
    
    % 存储该年份的季节平均结果
    for s = 1:4
        season = season_names{s};
        seasonal_metrics.(season).frequency(:,:,y) = season_freq(:,:,s);
        seasonal_metrics.(season).duration(:,:,y) = season_dur(:,:,s);
        % 强度为事件平均强度的平均
        seasonal_metrics.(season).intensity(:,:,y) = season_intensity_sum(:,:,s) ./ max(season_intensity_cnt(:,:,s), 1);
    end
    
    fprintf('已完成季节分析: %d\n', current_year);
end

% 将未发生事件的网格点强度设为 NaN（而不是0），避免影响统计
for s = 1:4
    season = season_names{s};
    mask = (seasonal_metrics.(season).frequency == 0);
    seasonal_metrics.(season).intensity(mask) = NaN;
    seasonal_metrics.(season).duration(mask) = NaN;
end

fprintf('季节变化分析（稳健版）完成。\n');

%% 6. 提取分析期数据
fprintf('提取分析期数据...\n');

% 找到分析期的索引
analysis_idx = find(ismember(full_years, analysis_years));
historical_idx = find(ismember(full_years, historical_years));

% 提取分析期数据
hw_frequency_analysis = hw_metrics.frequency(:, :, analysis_idx);
hw_duration_analysis = hw_metrics.duration(:, :, analysis_idx);
hw_intensity_analysis = hw_metrics.intensity(:, :, analysis_idx);

% 提取历史期数据
hw_frequency_historical = hw_metrics.frequency(:, :, historical_idx);
hw_duration_historical = hw_metrics.duration(:, :, historical_idx);
hw_intensity_historical = hw_metrics.intensity(:, :, historical_idx);

% 计算多年平均值
mean_frequency = mean(hw_frequency_analysis, 3, 'omitnan');
mean_duration = mean(hw_duration_analysis, 3, 'omitnan');
mean_intensity = mean(hw_intensity_analysis, 3, 'omitnan');

% 计算季节平均值
seasonal_means = struct();
for s = 1:length(season_names)
    season = season_names{s};
    seasonal_data = seasonal_metrics.(season).frequency(:, :, analysis_idx);
    % 检查数据有效性
    if all(isnan(seasonal_data(:)))
        seasonal_means.(season).frequency = NaN;
    else
        seasonal_means.(season).frequency = mean(seasonal_data, 3, 'omitnan');
    end
end

%% 7. 统计分析：近10年变化显著性
fprintf('进行统计分析：近10年变化显著性...\n');

% 初始化显著性检验结果
significance = struct();
significance.frequency = zeros(size(mean_frequency));
significance.duration = zeros(size(mean_duration));
significance.intensity = zeros(size(mean_intensity));

% 对每个网格点进行t检验，比较历史期和分析期的差异
for i = 1:size(hw_frequency_analysis, 1)
    for j = 1:size(hw_frequency_analysis, 2)
        % 提取时间序列
        hist_freq = squeeze(hw_frequency_historical(i, j, :));
        ana_freq = squeeze(hw_frequency_analysis(i, j, :));
        
        hist_dur = squeeze(hw_duration_historical(i, j, :));
        ana_dur = squeeze(hw_duration_analysis(i, j, :));
        
        hist_int = squeeze(hw_intensity_historical(i, j, :));
        ana_int = squeeze(hw_intensity_analysis(i, j, :));
        
        % 跳过缺失数据点
        if all(isnan(hist_freq)) || all(isnan(ana_freq)) || ...
           all(isnan(hist_dur)) || all(isnan(ana_dur)) || ...
           all(isnan(hist_int)) || all(isnan(ana_int))
            continue;
        end
        
        % 频率t检验
        try
            [~, p_freq] = ttest2(hist_freq, ana_freq);
            significance.frequency(i, j) = p_freq < 0.05; % 显著性水平0.05
        catch
            significance.frequency(i, j) = 0;
        end
        
        % 持续时间t检验
        try
            [~, p_dur] = ttest2(hist_dur, ana_dur);
            significance.duration(i, j) = p_dur < 0.05;
        catch
            significance.duration(i, j) = 0;
        end
        
        % 强度t检验
        try
            [~, p_int] = ttest2(hist_int, ana_int);
            significance.intensity(i, j) = p_int < 0.05;
        catch
            significance.intensity(i, j) = 0;
        end
    end
end

% 计算区域平均变化百分比
regional_freq_historical = squeeze(mean(mean(hw_frequency_historical, 1, 'omitnan'), 2, 'omitnan'));
regional_freq_analysis = squeeze(mean(mean(hw_frequency_analysis, 1, 'omitnan'), 2, 'omitnan'));
percent_change_freq = (mean(regional_freq_analysis) - mean(regional_freq_historical)) / mean(regional_freq_historical) * 100;

regional_dur_historical = squeeze(mean(mean(hw_duration_historical, 1, 'omitnan'), 2, 'omitnan'));
regional_dur_analysis = squeeze(mean(mean(hw_duration_analysis, 1, 'omitnan'), 2, 'omitnan'));
percent_change_dur = (mean(regional_dur_analysis) - mean(regional_dur_historical)) / mean(regional_dur_historical) * 100;

regional_int_historical = squeeze(mean(mean(hw_intensity_historical, 1, 'omitnan'), 2, 'omitnan'));
regional_int_analysis = squeeze(mean(mean(hw_intensity_analysis, 1, 'omitnan'), 2, 'omitnan'));
percent_change_int = (mean(regional_int_analysis) - mean(regional_int_historical)) / mean(regional_int_historical) * 100;

%% 8. Visualization Results
fprintf('Generating visualization results...\n');

% ==================== 8.1 Time Series Analysis (三个子图一排，近似正方形) ====================
figure('Position', [100, 100, 1400, 800], 'Color', 'w');

% 手动设置子图位置 [left, bottom, width, height]
% 使每个子图的绘图区域接近正方形（宽高比约0.47，考虑到坐标轴标签后视觉上近似正方形）
subplot_positions = {[0.07, 0.25, 0.26, 0.55], ...
                     [0.37, 0.25, 0.26, 0.55], ...
                     [0.67, 0.25, 0.26, 0.55]};

% 子图1：热浪频率年际变化
subplot('Position', subplot_positions{1})
hold on;
plot(historical_years, regional_freq_historical, 'b-o', 'LineWidth', 1, ...
    'MarkerFaceColor', 'b', 'MarkerSize', 3)
plot(analysis_years, regional_freq_analysis, 'r-o', 'LineWidth', 2, ...
    'MarkerFaceColor', 'r', 'MarkerSize', 4)
if length(historical_years) > 5
    p_hist = polyfit(historical_years, regional_freq_historical, 1);
    trend_hist = polyval(p_hist, historical_years);
    plot(historical_years, trend_hist, 'b--', 'LineWidth', 1.5)
end
if length(analysis_years) > 1
    p_ana = polyfit(analysis_years, regional_freq_analysis, 1);
    trend_ana = polyval(p_ana, analysis_years);
    plot(analysis_years, trend_ana, 'r--', 'LineWidth', 2)
end
title('Heatwave Frequency', 'FontWeight', 'bold')
xlabel('Year', 'FontWeight', 'bold')
ylabel('Frequency (events)', 'FontWeight', 'bold')
legend('1982-2014', '2015-2024', 'Location', 'best', 'FontWeight', 'bold')
grid on
set(gca, 'FontWeight', 'bold')

% 子图2：热浪持续时间年际变化
subplot('Position', subplot_positions{2})
hold on;
plot(historical_years, regional_dur_historical, 'b-o', 'LineWidth', 1, ...
    'MarkerFaceColor', 'b', 'MarkerSize', 3)
plot(analysis_years, regional_dur_analysis, 'r-o', 'LineWidth', 2, ...
    'MarkerFaceColor', 'r', 'MarkerSize', 4)
if length(historical_years) > 5
    p_hist = polyfit(historical_years, regional_dur_historical, 1);
    trend_hist = polyval(p_hist, historical_years);
    plot(historical_years, trend_hist, 'b--', 'LineWidth', 1.5)
end
if length(analysis_years) > 1
    p_ana = polyfit(analysis_years, regional_dur_analysis, 1);
    trend_ana = polyval(p_ana, analysis_years);
    plot(analysis_years, trend_ana, 'r--', 'LineWidth', 2)
end
title('Heatwave Duration', 'FontWeight', 'bold')
xlabel('Year', 'FontWeight', 'bold')
ylabel('Duration (days)', 'FontWeight', 'bold')
legend('1982-2014', '2015-2024', 'Location', 'best', 'FontWeight', 'bold')
grid on
set(gca, 'FontWeight', 'bold')

% 子图3：热浪强度年际变化
subplot('Position', subplot_positions{3})
hold on;
plot(historical_years, regional_int_historical, 'b-o', 'LineWidth', 1, ...
    'MarkerFaceColor', 'b', 'MarkerSize', 3)
plot(analysis_years, regional_int_analysis, 'r-o', 'LineWidth', 2, ...
    'MarkerFaceColor', 'r', 'MarkerSize', 4)
if length(historical_years) > 5
    p_hist = polyfit(historical_years, regional_int_historical, 1);
    trend_hist = polyval(p_hist, historical_years);
    plot(historical_years, trend_hist, 'b--', 'LineWidth', 1.5)
end
if length(analysis_years) > 1
    p_ana = polyfit(analysis_years, regional_int_analysis, 1);
    trend_ana = polyval(p_ana, analysis_years);
    plot(analysis_years, trend_ana, 'r--', 'LineWidth', 2)
end
title('Heatwave Intensity', 'FontWeight', 'bold')
xlabel('Year', 'FontWeight', 'bold')
ylabel('Intensity (°C)', 'FontWeight', 'bold')
legend('1982-2014', '2015-2024', 'Location', 'best', 'FontWeight', 'bold')
grid on
set(gca, 'FontWeight', 'bold')

% ==================== 8.2 Statistical Significance Test Results ====================
figure('Position', [100, 100, 1500, 500], 'Color', 'w');

% 频率显著性
subplot(1,3,1)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, significance.frequency);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
title('Frequency Change Significance', 'FontWeight', 'bold')
colormap([0.8 0.8 0.8; 1 0 0])
c = colorbar('Ticks', [0.25, 0.75], 'TickLabels', {'Not Significant', 'Significant'});
set(c, 'FontWeight', 'bold');
% 强制加粗所有文本（包括经纬度）
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% 持续时间显著性
subplot(1,3,2)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, significance.duration);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
title('Duration Change Significance', 'FontWeight', 'bold')
colormap([0.8 0.8 0.8; 1 0 0])
c = colorbar('Ticks', [0.25, 0.75], 'TickLabels', {'Not Significant', 'Significant'});
set(c, 'FontWeight', 'bold');
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% 强度显著性
subplot(1,3,3)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, significance.intensity);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
title('Intensity Change Significance', 'FontWeight', 'bold')
colormap([0.8 0.8 0.8; 1 0 0])
c = colorbar('Ticks', [0.25, 0.75], 'TickLabels', {'Not Significant', 'Significant'});
set(c, 'FontWeight', 'bold');
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% ==================== 8.3 Spatial Distribution of Recent Decadal Changes ====================
figure('Position', [100, 100, 1500, 500], 'Color', 'w');

% 计算百分比变化
freq_change = (mean_frequency - mean(hw_frequency_historical, 3, 'omitnan')) ...
              ./ mean(hw_frequency_historical, 3, 'omitnan') * 100;
dur_change  = (mean_duration - mean(hw_duration_historical, 3, 'omitnan')) ...
              ./ mean(hw_duration_historical, 3, 'omitnan') * 100;
int_change  = (mean_intensity - mean(hw_intensity_historical, 3, 'omitnan')) ...
              ./ mean(hw_intensity_historical, 3, 'omitnan') * 100;

% 频率变化百分比
subplot(1,3,1)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, freq_change);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
c = colorbar('southoutside');
c.Label.String = 'Frequency change (%)';
c.Label.FontWeight = 'bold';
c.Label.FontSize = 12;
set(c, 'FontWeight', 'bold');
caxis([-50 250])
title('Frequency Change (%)', 'FontWeight', 'bold')
colormap(redblue)
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% 持续时间变化百分比
subplot(1,3,2)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, dur_change);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
c = colorbar('southoutside');
c.Label.String = 'Duration change (%)';
c.Label.FontWeight = 'bold';
c.Label.FontSize = 12;
set(c, 'FontWeight', 'bold');
caxis([-50 250])
title('Duration Change (%)', 'FontWeight', 'bold')
colormap(redblue)
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% 强度变化百分比
subplot(1,3,3)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, int_change);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
c = colorbar('southoutside');
c.Label.String = 'Intensity change (%)';
c.Label.FontWeight = 'bold';
c.Label.FontSize = 12;
set(c, 'FontWeight', 'bold');
caxis([-50 100])
title('Intensity Change (%)', 'FontWeight', 'bold')
colormap(redblue)
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

drawnow;% ==================== 8.3 Spatial Distribution of Recent Decadal Changes ====================
figure('Position', [100, 100, 1500, 500], 'Color', 'w');

% 计算百分比变化
freq_change = (mean_frequency - mean(hw_frequency_historical, 3, 'omitnan')) ...
              ./ mean(hw_frequency_historical, 3, 'omitnan') * 100;
dur_change  = (mean_duration - mean(hw_duration_historical, 3, 'omitnan')) ...
              ./ mean(hw_duration_historical, 3, 'omitnan') * 100;
int_change  = (mean_intensity - mean(hw_intensity_historical, 3, 'omitnan')) ...
              ./ mean(hw_intensity_historical, 3, 'omitnan') * 100;

% 频率变化百分比
subplot(1,3,1)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, freq_change);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
c = colorbar('southoutside');
c.Label.String = '';   % 去掉标签
set(c, 'FontWeight', 'bold');
caxis([-50 250])
title('Frequency', 'FontWeight', 'bold')
colormap(redblue)
drawnow;
c_pos = get(c, 'Position'); % 获取色标位置
annotation('textbox', [c_pos(1)+c_pos(3)+0.005, c_pos(2)+c_pos(4)/2, 0, 0], ...
    'String', '%', 'FitBoxToText', 'on', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% 持续时间变化百分比
subplot(1,3,2)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, dur_change);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
c = colorbar('southoutside');
c.Label.String = '';
set(c, 'FontWeight', 'bold');
caxis([-50 250])
title('Duration', 'FontWeight', 'bold')
colormap(redblue)
drawnow;
c_pos = get(c, 'Position');
annotation('textbox', [c_pos(1)+c_pos(3)+0.005, c_pos(2)+c_pos(4)/2, 0, 0], ...
    'String', '%', 'FitBoxToText', 'on', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

% 强度变化百分比
subplot(1,3,3)
m_proj('mercator', 'lon', target_lon, 'lat', target_lat);
m_pcolor(region_lon, region_lat, int_change);
shading flat;
m_coast('patch', [0.8 0.8 0.8], 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontweight', 'bold', 'fontsize', 12);
c = colorbar('southoutside');
c.Label.String = '';
set(c, 'FontWeight', 'bold');
caxis([-50 100])
title('Intensity', 'FontWeight', 'bold')
colormap(redblue)
drawnow;
c_pos = get(c, 'Position');
annotation('textbox', [c_pos(1)+c_pos(3)+0.005, c_pos(2)+c_pos(4)/2, 0, 0], ...
    'String', '%', 'FitBoxToText', 'on', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontWeight', 'bold');
all_text = findall(gca, 'Type', 'text');
set(all_text, 'FontWeight', 'bold');

drawnow;

%% 9. 统计分析与报告生成
fprintf('生成统计分析报告...\n');

% 计算区域统计
region_stats = struct();
region_stats.mean_frequency = mean(mean_frequency(:), 'omitnan');
region_stats.mean_duration = mean(mean_duration(:), 'omitnan');
region_stats.mean_intensity = mean(mean_intensity(:), 'omitnan');

% 计算变化百分比
region_stats.percent_change_freq = percent_change_freq;
region_stats.percent_change_dur = percent_change_dur;
region_stats.percent_change_int = percent_change_int;

% 计算显著性区域比例
region_stats.significant_freq = sum(significance.frequency(:)) / numel(significance.frequency) * 100;
region_stats.significant_dur = sum(significance.duration(:)) / numel(significance.duration) * 100;
region_stats.significant_int = sum(significance.intensity(:)) / numel(significance.intensity) * 100;

% 计算季节统计
for s = 1:length(season_names)
    season = season_names{s};
    seasonal_data = seasonal_means.(season).frequency;
    if ~isnan(seasonal_data)
        region_stats.(['mean_freq_', season]) = mean(seasonal_data(:), 'omitnan');
    else
        region_stats.(['mean_freq_', season]) = 0;
    end
end

% 显示统计结果
fprintf('\n=== 北太平洋西部海洋热浪统计分析(2015-2024 vs 1982-2014) ===\n');
fprintf('区域: %.1f-%.1f°N, %.1f-%.1f°E\n', target_lat(1), target_lat(2), target_lon(1), target_lon(2));
fprintf('平均热浪频率: %.2f 次/年 (变化: +%.1f%%)\n', region_stats.mean_frequency, region_stats.percent_change_freq);
fprintf('平均热浪持续时间: %.2f 天 (变化: +%.1f%%)\n', region_stats.mean_duration, region_stats.percent_change_dur);
fprintf('平均热浪强度: %.2f °C (变化: +%.1f%%)\n', region_stats.mean_intensity, region_stats.percent_change_int);
fprintf('显著性变化区域比例 - 频率: %.1f%%, 持续时间: %.1f%%, 强度: %.1f%%\n', ...
    region_stats.significant_freq, region_stats.significant_dur, region_stats.significant_int);

fprintf('\n季节平均热浪频率:\n');
for s = 1:length(season_names)
    season = season_names{s};
    fprintf('  %s: %.2f 次/季节\n', season, region_stats.(['mean_freq_', season]));
end

%% 10. 保存结果
fprintf('保存结果...\n');

% 保存统计结果
save(fullfile(result_dir, 'oisst_heatwave_analysis.mat'), ...
    'region_stats', 'mean_frequency', 'mean_duration', 'mean_intensity', ...
    'significance', 'seasonal_means', 'analysis_years', 'region_lat', 'region_lon', ...
    'regional_freq_historical', 'regional_freq_analysis', ...
    'regional_dur_historical', 'regional_dur_analysis', ...
    'regional_int_historical', 'regional_int_analysis');

% 保存图像
print(fullfile(result_dir, 'oisst_heatwave_temporal_analysis.png'), '-dpng', '-r300');
print(fullfile(result_dir, 'oisst_heatwave_significance.png'), '-dpng', '-r300');
print(fullfile(result_dir, 'oisst_heatwave_percent_change.png'), '-dpng', '-r300');

% 生成报告
report_file = fullfile(result_dir, 'oisst_heatwave_analysis_report.txt');
fid = fopen(report_file, 'w');
fprintf(fid, '基于OISST数据的北太平洋西部海洋热浪分析报告\n');
fprintf(fid, '分析区域: %.1f-%.1f°N, %.1f-%.1f°E\n', target_lat(1), target_lat(2), target_lon(1), target_lon(2));
fprintf(fid, '分析时段: %d-%d年 (对比: %d-%d年)\n', analysis_years(1), analysis_years(end), historical_years(1), historical_years(end));
fprintf(fid, '气候基准期: %d-%d年\n', baseline_years(1), baseline_years(end));
fprintf(fid, '生成时间: %s\n\n', datestr(now));

fprintf(fid, '主要统计结果:\n');
fprintf(fid, '平均热浪频率: %.2f 次/年 (变化: +%.1f%%)\n', region_stats.mean_frequency, region_stats.percent_change_freq);
fprintf(fid, '平均热浪持续时间: %.2f 天 (变化: +%.1f%%)\n', region_stats.mean_duration, region_stats.percent_change_dur);
fprintf(fid, '平均热浪强度: %.2f °C (变化: +%.1f%%)\n', region_stats.mean_intensity, region_stats.percent_change_int);
fprintf(fid, '显著性变化区域比例 - 频率: %.1f%%, 持续时间: %.1f%%, 强度: %.1f%%\n', ...
    region_stats.significant_freq, region_stats.significant_dur, region_stats.significant_int);

fprintf(fid, '\n季节平均热浪频率:\n');
for s = 1:length(season_names)
    season = season_names{s};
    fprintf(fid, '  %s: %.2f 次/季节\n', season, region_stats.(['mean_freq_', season]));
end

fprintf(fid, '\n主要结论:\n');
fprintf(fid, '1. 2015-2024年间，北太平洋西部海洋热浪频率、持续时间和强度均显著增加。\n');
fprintf(fid, '2. 热浪频率增加最为明显，区域平均增加%.1f%%。\n', region_stats.percent_change_freq);
fprintf(fid, '3. 约%.1f%%的区域显示出热浪频率的显著性增加。\n', region_stats.significant_freq);

% 找出最频繁的季节
season_freqs = [region_stats.mean_freq_Winter, region_stats.mean_freq_Spring, ...
                region_stats.mean_freq_Summer, region_stats.mean_freq_Autumn];
[~, max_season_idx] = max(season_freqs);
fprintf(fid, '4. 季节分析显示，%s季的热浪活动最为频繁。\n', season_names{max_season_idx});

fclose(fid);

fprintf('分析完成! 结果已保存至: %s\n', result_dir);

%% 辅助函数: 识别连续热浪事件 (至少5天)
function events = identify_heatwave_events(ts)
    events = [];
    event_start = 0;
    event_end = 0;
    in_event = false;
    
    for t = 1:length(ts)
        if ts(t) == 1
            if ~in_event
                % 新事件开始
                in_event = true;
                event_start = t;
                event_end = t;
            else
                % 延续现有事件
                event_end = t;
            end
        else
            if in_event
                % 事件结束
                duration = event_end - event_start + 1;
                if duration >= 5
                    events = [events; struct('start', event_start, 'end', event_end, 'duration', duration)];
                end
                in_event = false;
            end
        end
    end
    
    % 检查最后一个事件
    if in_event
        duration = event_end - event_start + 1;
        if duration >= 5
            events = [events; struct('start', event_start, 'end', event_end, 'duration', duration)];
        end
    end
end

%% 辅助函数: 判断闰年
function is_leap = leapyear(year)
    is_leap = (mod(year, 4) == 0 & mod(year, 100) ~= 0) | (mod(year, 400) == 0);
end

%% 辅助函数: 红蓝颜色映射
function cmap = redblue(m)
    if nargin < 1
        m = 64;
    end
    
    % 创建红蓝颜色映射
    top = [0.5 0 0];    % 深红
    center = [1 1 1];   % 白色
    bottom = [0 0 0.5]; % 深蓝
    
    % 上半部分 (白到红)
    r1 = linspace(center(1), top(1), m/2);
    g1 = linspace(center(2), top(2), m/2);
    b1 = linspace(center(3), top(3), m/2);
    
    % 下半部分 (蓝到白)
    r2 = linspace(bottom(1), center(1), m/2);
    g2 = linspace(bottom(2), center(2), m/2);
    b2 = linspace(bottom(3), center(3), m/2);
    
    % 合并颜色映射
    cmap = [r2', g2', b2'; r1', g1', b1'];
end