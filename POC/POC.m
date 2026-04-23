%% POC与海洋热浪关联分析 
clear;
close all;
clc;

%% 参数设置
lon_range = [110, 180]; % 东经110-180度
lat_range = [30, 60];  % 北纬30-60度
target_years = 2015:2024;  % 分析年份
baseline_years = 2005:2014; % 基准期年份

% 文件路径 - 修改为POC数据路径
poc_data_file = 'F:\POC\poc7d\Unet_t1_POC_ds_combined.nc'; % 13.6G的8天平均POC数据文件
hw_events_dir  = 'D:\dlb\m_mhw1.0-master\m_mhw1.0-master\data\global\marine_heatwave_results\'; % 热浪事件文件路径
output_dir = 'poc_heatwave_analysis'; % 输出目录

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('开始POC与海洋热浪关联分析（8天平均数据）...\n');
fprintf('POC数据文件: %s\n', poc_data_file);
fprintf('文件大小: 13.6 GB\n');
fprintf('数据时间分辨率: 8天平均\n');

%% 第一步：读取POC数据信息
fprintf('读取POC数据信息...\n');

% 检查POC数据文件是否存在
if ~exist(poc_data_file, 'file')
    error('POC数据文件不存在: %s\n请检查文件路径是否正确。', poc_data_file);
end

% 获取netCDF文件信息
try
    % 获取文件信息
    nc_info = ncinfo(poc_data_file);
    
    % 查找POC变量
    var_found = false;
    poc_var_name = '';
    for i = 1:length(nc_info.Variables)
        var_name = nc_info.Variables(i).Name;
        if strcmpi(var_name, 'POC-pred') || strcmpi(var_name, 'poc_pred') || ...
           strcmpi(var_name, 'poc') || strcmpi(var_name, 'POC')
            poc_var_name = var_name;
            var_found = true;
            fprintf('找到POC变量: %s\n', poc_var_name);
            break;
        end
    end
    
    if ~var_found
        % 尝试查找其他可能的变量名
        fprintf('未找到标准POC变量名，尝试其他变量...\n');
        for i = 1:length(nc_info.Variables)
            var_name = nc_info.Variables(i).Name;
            if contains(lower(var_name), 'poc') || contains(lower(var_name), 'carbon')
                poc_var_name = var_name;
                var_found = true;
                fprintf('找到可能的POC变量: %s\n', var_name);
                break;
            end
        end
    end
    
    if ~var_found
        error('在文件中找不到POC变量。可用的变量包括: %s', ...
              strjoin({nc_info.Variables.Name}, ', '));
    end
    
    % 获取维度信息
    var_info = nc_info.Variables(strcmp({nc_info.Variables.Name}, poc_var_name));
    dim_names = {var_info.Dimensions.Name};
    dim_sizes = [var_info.Dimensions.Length];
    
    % 确定维度顺序 - 通常是(time, lat, lon)或(time, lon, lat)
    time_idx = find(contains(dim_names, 'time', 'IgnoreCase', true), 1);
    lon_idx = find(contains(dim_names, {'lon', 'longitude', 'x'}, 'IgnoreCase', true), 1);
    lat_idx = find(contains(dim_names, {'lat', 'latitude', 'y'}, 'IgnoreCase', true), 1);
    
    if isempty(time_idx) || isempty(lon_idx) || isempty(lat_idx)
        error('无法确定时间、经度、纬度维度。请检查数据格式。');
    end
    
    % 获取维度大小
    n_time = dim_sizes(time_idx);
    n_lat = dim_sizes(lat_idx);
    n_lon = dim_sizes(lon_idx);
    
    fprintf('数据维度: 时间=%d, 纬度=%d, 经度=%d\n', n_time, n_lat, n_lon);
    
    % 读取经纬度数据
    fprintf('读取经纬度数据...\n');
    
    % 尝试读取纬度变量
    lat_var_names = {'lat', 'latitude', 'Lat', 'Latitude'};
    lat_data = [];
    for i = 1:length(lat_var_names)
        try
            lat_data = ncread(poc_data_file, lat_var_names{i});
            fprintf('找到纬度变量: %s\n', lat_var_names{i});
            break;
        catch
            continue;
        end
    end
    
    % 尝试读取经度变量
    lon_var_names = {'lon', 'longitude', 'Lon', 'Longitude'};
    lon_data = [];
    for i = 1:length(lon_var_names)
        try
            lon_data = ncread(poc_data_file, lon_var_names{i});
            fprintf('找到经度变量: %s\n', lon_var_names{i});
            break;
        catch
            continue;
        end
    end
    
    if isempty(lat_data) || isempty(lon_data)
        error('无法读取经纬度数据。请检查netCDF文件结构。');
    end
    
    % 读取时间变量
    fprintf('读取时间变量...\n');
    time_var_names = {'time', 'Time', 'date', 'Date'};
    time_data = [];
    time_units = '';
    time_calendar = '';
    
    for i = 1:length(time_var_names)
        try
            time_data = ncread(poc_data_file, time_var_names{i});
            time_units = ncreadatt(poc_data_file, time_var_names{i}, 'units');
            try
                time_calendar = ncreadatt(poc_data_file, time_var_names{i}, 'calendar');
            catch
                time_calendar = 'standard';
            end
            fprintf('找到时间变量: %s\n', time_var_names{i});
            fprintf('时间单位: %s\n', time_units);
            fprintf('时间日历: %s\n', time_calendar);
            break;
        catch
            continue;
        end
    end
    
    if isempty(time_data)
        error('无法读取时间变量。请检查netCDF文件结构。');
    end
    
catch ME
    error('读取POC数据信息失败: %s', ME.message);
end

%% 第二步：处理时间信息（8天平均数据）
fprintf('处理时间信息（8天平均）...\n');

% 尝试使用MATLAB内置的时间转换
try
    % 首先检查时间变量是否有units属性
    if contains(time_units, 'since')
        % 提取参考日期
        ref_str = extractAfter(time_units, 'since');
        ref_str = strtrim(ref_str);
        
        % 尝试解析参考日期
        try
            ref_date = datetime(ref_str);
        catch
            % 如果失败，尝试常见的格式
            try
                % 尝试完整格式 'yyyy-MM-dd HH:mm:ss'
                ref_date = datetime(ref_str, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
            catch
                try
                    % 尝试只有日期的格式 'yyyy-MM-dd'
                    ref_date = datetime(ref_str, 'InputFormat', 'yyyy-MM-dd');
                catch
                    try
                        % 尝试其他格式
                        ref_date = datetime(ref_str, 'InputFormat', 'dd-MMM-yyyy');
                    catch
                        % 使用默认参考日期
                        ref_date = datetime(2000, 1, 1);
                        fprintf('使用默认参考日期: %s\n', datestr(ref_date));
                    end
                end
            end
        end
        
        % 检查时间单位并转换
        if contains(time_units, 'days')
            all_dates = ref_date + days(time_data);
        elseif contains(time_units, 'hours')
            all_dates = ref_date + hours(time_data);
        elseif contains(time_units, 'minutes')
            all_dates = ref_date + minutes(time_data);
        else
            % 默认为天
            all_dates = ref_date + days(time_data);
        end
    else
        % 尝试直接转换
        all_dates = datetime(time_data, 'ConvertFrom', 'datenum');
    end
catch
    fprintf('使用自定义时间转换方法...\n');
    
    % 如果无法确定时间单位，创建基于8天间隔的时间序列
    fprintf('警告：无法确定时间单位，假设为8天间隔\n');
    start_date = datetime(2000, 1, 1);
    all_dates = start_date + days(0:8:(n_time-1)*8)';
end

% 提取年份、月份和年积日
all_years = year(all_dates);
all_months = month(all_dates);
all_doy = day(all_dates, 'dayofyear');

fprintf('时间范围: %s 到 %s\n', datestr(min(all_dates)), datestr(max(all_dates)));
fprintf('总时间点数: %d\n', length(all_dates));

%% 第三步：确定研究区域的空间索引
fprintf('确定研究区域的空间索引...\n');

% 如果经纬度是1D数组，创建网格
if isvector(lat_data) && isvector(lon_data)
    [LON, LAT] = meshgrid(lon_data, lat_data);
else
    LON = lon_data;
    LAT = lat_data;
end

% 检查经纬度顺序和范围
% 对于经度，通常范围是-180到180或0到360
% 对于纬度，通常范围是-90到90
fprintf('经度范围: %.2f 到 %.2f\n', min(LON(:)), max(LON(:)));
fprintf('纬度范围: %.2f 到 %.2f\n', min(LAT(:)), max(LAT(:)));

% 调整经度范围（如果经度范围是0-360而研究区域是110-180）
if max(LON(:)) > 180 && lon_range(1) > 0
    % 经度范围已经是0-360，不需要调整
elseif max(LON(:)) > 180 && lon_range(1) < 0
    % 需要将研究区域的经度转换为0-360范围
    lon_range = mod(lon_range + 360, 360);
    fprintf('调整研究区域经度范围到0-360系统: [%.1f, %.1f]\n', lon_range(1), lon_range(2));
end

% 确定研究区域的索引
lon_mask = LON >= lon_range(1) & LON <= lon_range(2);
lat_mask = LAT >= lat_range(1) & LAT <= lat_range(2);
region_mask = lon_mask & lat_mask;

% 获取边界索引
[rows, cols] = find(region_mask);
if isempty(rows)
    error('研究区域内没有数据点。请检查经纬度范围。');
end

min_row = min(rows);
max_row = max(rows);
min_col = min(cols);
max_col = max(cols);

% 提取研究区域的经纬度
lon_region = LON(min_row:max_row, min_col:max_col);
lat_region = LAT(min_row:max_row, min_col:max_col);
[nlat_region, nlon_region] = size(lon_region);

fprintf('研究区域大小: 纬度点数=%d, 经度点数=%d\n', nlat_region, nlon_region);

%% 第四步：分块读取数据以节省内存
fprintf('分块读取POC数据...\n');

% 选择2005-2024年的数据（包含基准期和分析期）
analysis_mask = all_years >= 2005 & all_years <= 2024;
analysis_dates = all_dates(analysis_mask);
analysis_years = all_years(analysis_mask);
analysis_doy = all_doy(analysis_mask);
analysis_months = all_months(analysis_mask);
analysis_indices = find(analysis_mask);

n_analysis_times = length(analysis_indices);
fprintf('分析期时间点数（2005-2024）: %d\n', n_analysis_times);

% 预分配分析期数据数组（分块处理）
poc_analysis_data = NaN(nlat_region, nlon_region, n_analysis_times);
hw_mask_npp_grid = false(n_analysis_times, nlat_region, nlon_region); % 预分配热浪掩码

% 定义块大小（每次处理的时间点数）
chunk_size = 50; % 根据内存调整
n_chunks = ceil(n_analysis_times / chunk_size);

fprintf('分块处理数据，块大小: %d，总块数: %d\n', chunk_size, n_chunks);

% 分块读取和处理数据
for chunk_idx = 1:n_chunks
    fprintf('处理块 %d/%d...\n', chunk_idx, n_chunks);
    
    % 确定当前块的索引范围
    start_idx = (chunk_idx - 1) * chunk_size + 1;
    end_idx = min(chunk_idx * chunk_size, n_analysis_times);
    chunk_indices = start_idx:end_idx;
    chunk_global_indices = analysis_indices(chunk_indices);
    
    % 读取当前块的POC数据
    try
        % 读取整个研究区域的数据
        % 注意：这里假设维度顺序是(time, lat, lon)
        % 如果维度顺序不同，需要调整
        
        % 尝试不同的维度顺序
        if time_idx == 1 && lat_idx == 2 && lon_idx == 3
            % 维度顺序: time, lat, lon
            start_pos = [min(chunk_global_indices), min_row, min_col];
            count = [length(chunk_global_indices), nlat_region, nlon_region];
            poc_chunk = ncread(poc_data_file, poc_var_name, start_pos, count);
            
            % 重新排列维度到 (lat, lon, time)
            poc_chunk = permute(poc_chunk, [2, 3, 1]);
            
        elseif time_idx == 1 && lon_idx == 2 && lat_idx == 3
            % 维度顺序: time, lon, lat
            start_pos = [min(chunk_global_indices), min_col, min_row];
            count = [length(chunk_global_indices), nlon_region, nlat_region];
            poc_chunk = ncread(poc_data_file, poc_var_name, start_pos, count);
            
            % 重新排列维度到 (lat, lon, time)
            poc_chunk = permute(poc_chunk, [3, 2, 1]);
            
        else
            % 尝试通用方法
            fprintf('尝试通用读取方法...\n');
            
            % 确定每个维度的起始位置和计数
            start_pos = ones(1, length(dim_sizes));
            count = ones(1, length(dim_sizes));
            
            % 设置时间维度
            start_pos(time_idx) = min(chunk_global_indices);
            count(time_idx) = length(chunk_global_indices);
            
            % 设置空间维度
            if lat_idx < lon_idx
                % lat在前
                start_pos(lat_idx) = min_row;
                count(lat_idx) = nlat_region;
                start_pos(lon_idx) = min_col;
                count(lon_idx) = nlon_region;
            else
                % lon在前
                start_pos(lon_idx) = min_col;
                count(lon_idx) = nlon_region;
                start_pos(lat_idx) = min_row;
                count(lat_idx) = nlat_region;
            end
            
            poc_chunk = ncread(poc_data_file, poc_var_name, start_pos, count);
            
            % 重新排列维度到 (lat, lon, time)
            % 首先找到每个维度的位置
            dim_order = [lat_idx, lon_idx, time_idx];
            [~, sort_idx] = sort(dim_order);
            poc_chunk = permute(poc_chunk, sort_idx);
        end
        
        % 处理缺失值（假设缺失值为NaN或非常大的负值）
        poc_chunk(poc_chunk > 1e10) = NaN;
        poc_chunk(poc_chunk < -1e10) = NaN;
        
        % 将数据存储到分析数组
        poc_analysis_data(:, :, chunk_indices) = poc_chunk;
        
        fprintf('  已读取块 %d: 时间点 %d-%d\n', chunk_idx, start_idx, end_idx);
        
    catch ME
        fprintf('  读取块 %d 时出错: %s\n', chunk_idx, ME.message);
        
        % 尝试更保守的方法：逐个时间点读取
        fprintf('  尝试逐个时间点读取...\n');
        
        for i = 1:length(chunk_indices)
            idx = chunk_indices(i);
            global_idx = analysis_indices(idx);
            
            try
                % 读取单个时间点的数据
                if time_idx == 1 && lat_idx == 2 && lon_idx == 3
                    poc_single = ncread(poc_data_file, poc_var_name, ...
                        [global_idx, min_row, min_col], [1, nlat_region, nlon_region]);
                    poc_single = squeeze(poc_single);
                else
                    % 尝试其他维度顺序
                    poc_single = ncread(poc_data_file, poc_var_name, ...
                        [global_idx, 1, 1], [1, Inf, Inf]);
                    poc_single = squeeze(poc_single);
                    
                    % 提取研究区域
                    poc_single = poc_single(min_row:max_row, min_col:max_col);
                end
                
                poc_single(poc_single > 1e10) = NaN;
                poc_analysis_data(:, :, idx) = poc_single;
                
            catch ME2
                fprintf('    时间点 %d 读取失败: %s\n', idx, ME2.message);
            end
        end
    end
end

fprintf('POC数据读取完成。\n');

%% 第五步：计算基准期和异常
fprintf('计算基准期和POC异常...\n');

% 分离基准期和分析期
baseline_mask = analysis_years >= 2005 & analysis_years <= 2014;
analysis_period_mask = analysis_years >= 2015 & analysis_years <= 2024;

baseline_indices = find(baseline_mask);
analysis_period_indices = find(analysis_period_mask);

baseline_dates = analysis_dates(baseline_indices);
baseline_years_data = analysis_years(baseline_indices);
baseline_doy = analysis_doy(baseline_indices);

analysis_period_dates = analysis_dates(analysis_period_indices);
analysis_period_years = analysis_years(analysis_period_indices);
analysis_period_doy = analysis_doy(analysis_period_indices);

fprintf('基准期: %s 到 %s (%d个时间点)\n', ...
    datestr(min(baseline_dates)), datestr(max(baseline_dates)), length(baseline_indices));
fprintf('分析期: %s 到 %s (%d个时间点)\n', ...
    datestr(min(analysis_period_dates)), datestr(max(analysis_period_dates)), length(analysis_period_indices));

% 由于是8天平均数据，每个年积日可能对应多个时间点
% 我们需要按年积日分组计算基准期气候态

% 计算每个年积日的基准期平均值
fprintf('计算每个年积日的基准期气候态...\n');

% 获取唯一的年积日（1-366）
unique_doy = unique(baseline_doy);
n_unique_doy = length(unique_doy);

% 预分配基准期气候态数组
baseline_climatology = NaN(nlat_region, nlon_region, 366); % 366天

% 为每个年积日计算基准期平均值
for i = 1:length(unique_doy)
    doy = unique_doy(i);
    
    % 找到基准期中对应年积日的所有时间点
    doy_mask = baseline_doy == doy;
    if sum(doy_mask) > 0
        % 获取对应的时间点数据
        doy_indices = baseline_indices(doy_mask);
        doy_data = poc_analysis_data(:, :, doy_indices);
        
        % 计算多年平均
        baseline_climatology(:, :, doy) = nanmean(doy_data, 3);
    end
end

% 对于缺失的年积日，使用线性插值
fprintf('插值缺失的年积日数据...\n');
for i = 1:nlat_region
    for j = 1:nlon_region
        ts = squeeze(baseline_climatology(i, j, :));
        if any(isnan(ts))
            % 使用线性插值填充缺失值
            ts_filled = fillmissing(ts, 'linear');
            baseline_climatology(i, j, :) = ts_filled;
        end
    end
end

% 计算分析期的POC异常
fprintf('计算分析期POC异常...\n');

poc_anomaly = NaN(nlat_region, nlon_region, length(analysis_period_indices));

for t = 1:length(analysis_period_indices)
    idx = analysis_period_indices(t);
    current_doy = analysis_period_doy(t);
    
    % 获取当前时间点的POC数据
    current_poc = poc_analysis_data(:, :, idx);
    
    % 获取对应年积日的基准值
    baseline_value = baseline_climatology(:, :, current_doy);
    
    % 计算异常
    poc_anomaly(:, :, t) = current_poc - baseline_value;
    
    % 更新进度
    if mod(t, 50) == 0
        fprintf('  已处理 %d/%d 个时间点...\n', t, length(analysis_period_indices));
    end
end

fprintf('POC异常计算完成。\n');

%% 第六步：加载热浪事件数据
fprintf('加载热浪事件数据...\n');

% 检查热浪事件目录是否存在
if ~exist(hw_events_dir, 'dir')
    error('热浪事件目录不存在: %s\n请检查目录路径是否正确。', hw_events_dir);
end

% 查找所有热浪事件文件
hw_files = dir(fullfile(hw_events_dir, 'marine_heatwave_events*.csv'));
if isempty(hw_files)
    error('在目录 %s 中找不到热浪事件文件', hw_events_dir);
end

fprintf('找到 %d 个热浪事件文件\n', length(hw_files));

% 加载所有热浪事件
all_hw_events = [];
for i = 1:length(hw_files)
    file_path = fullfile(hw_events_dir, hw_files(i).name);
    try
        events = readtable(file_path);
        
        % 检查列名并重命名（如果需要）
        if any(strcmp(events.Properties.VariableNames, 'start_data'))
            events.Properties.VariableNames{'start_data'} = 'start_date';
        end
        if any(strcmp(events.Properties.VariableNames, 'end_data'))
            events.Properties.VariableNames{'end_data'} = 'end_date';
        end
        
        % 确保日期列是datetime类型
        if iscell(events.start_date)
            events.start_date = datetime(events.start_date);
        end
        if iscell(events.end_date)
            events.end_date = datetime(events.end_date);
        end
        
        all_hw_events = [all_hw_events; events];
    catch ME
        fprintf('警告：无法读取文件 %s: %s\n', file_path, ME.message);
    end
end

fprintf('总共加载了 %d 个热浪事件\n', height(all_hw_events));

% 获取热浪事件的经纬度范围
hw_lons = unique(all_hw_events.lon);
hw_lats = unique(all_hw_events.lat);

% 创建热浪事件网格
n_lon_hw = length(hw_lons);
n_lat_hw = length(hw_lats);

% 创建一个三维数组来存储每个网格点的热浪掩码
hw_mask_hw_grid = false(length(analysis_period_dates), n_lon_hw, n_lat_hw);

% 为每个热浪事件创建掩码
fprintf('为热浪事件创建掩码...\n');
for i = 1:height(all_hw_events)
    % 获取事件的经纬度
    event_lon = all_hw_events.lon(i);
    event_lat = all_hw_events.lat(i);
    start_date = all_hw_events.start_date(i);
    end_date = all_hw_events.end_date(i);
    
    % 找到对应的网格点索引
    [~, lon_idx] = min(abs(hw_lons - event_lon));
    [~, lat_idx] = min(abs(hw_lats - event_lat));
    
    % 确保热浪事件在分析期日期范围内
    if start_date > analysis_period_dates(end) || end_date < analysis_period_dates(1)
        continue;
    end
    
    % 调整热浪事件日期以匹配分析期日期范围
    start_date = max(start_date, analysis_period_dates(1));
    end_date = min(end_date, analysis_period_dates(end));
    
    % 找到热浪事件在分析期日期范围内的索引
    event_mask = (analysis_period_dates >= start_date) & (analysis_period_dates <= end_date);
    
    % 更新热浪掩码
    hw_mask_hw_grid(:, lon_idx, lat_idx) = hw_mask_hw_grid(:, lon_idx, lat_idx) | event_mask;
    
    % 更新进度
    if mod(i, 1000) == 0
        fprintf('已处理 %d/%d 个热浪事件...\n', i, height(all_hw_events));
    end
end

%% 第七步：将热浪掩码映射到POC网格
fprintf('将热浪掩码映射到POC网格...\n');

% 使用meshgrid创建热浪网格
[X_hw, Y_hw] = meshgrid(hw_lons, hw_lats);
X_hw = X_hw'; % 转置以使维度匹配
Y_hw = Y_hw'; % 转置以使维度匹配

% 为每个POC网格点找到最近的热浪网格点索引
nearest_hw_idx = zeros(nlat_region, nlon_region, 2); % 存储经度和纬度索引

for i = 1:nlat_region
    for j = 1:nlon_region
        % 计算当前POC网格点到所有热浪网格点的距离
        dist = sqrt((X_hw - lon_region(i,j)).^2 + (Y_hw - lat_region(i,j)).^2);
        
        % 找到最小距离的索引
        [~, min_idx] = min(dist(:));
        
        % 转换为二维索引
        [lon_idx, lat_idx] = ind2sub(size(dist), min_idx);
        
        % 存储最近的热浪网格点索引
        nearest_hw_idx(i, j, 1) = lon_idx;
        nearest_hw_idx(i, j, 2) = lat_idx;
    end
    
    % 更新进度
    if mod(i, 10) == 0
        fprintf('已处理 %d/%d 个纬度点...\n', i, nlat_region);
    end
end

% 使用最近邻映射将热浪掩码从热浪网格映射到POC网格
fprintf('映射热浪掩码到POC网格...\n');

for t = 1:length(analysis_period_dates)
    % 获取当前时间点的热浪掩码
    hw_mask_t = squeeze(hw_mask_hw_grid(t, :, :));
    
    % 为每个POC网格点获取对应的热浪掩码
    for i = 1:nlat_region
        for j = 1:nlon_region
            % 获取最近的热浪网格点索引
            lon_idx = nearest_hw_idx(i, j, 1);
            lat_idx = nearest_hw_idx(i, j, 2);
            
            % 将热浪掩码映射到POC网格
            hw_mask_npp_grid(t, i, j) = hw_mask_t(lon_idx, lat_idx);
        end
    end
    
    % 更新进度
    if mod(t, 100) == 0
        fprintf('已映射 %d/%d 个时间点...\n', t, length(analysis_period_dates));
    end
end

%% 第八步：计算热浪期与非热浪期POC异常
fprintf('计算热浪期与非热浪期POC异常...\n');

% 初始化热浪期和非热浪期累加器
hw_sum = zeros(nlat_region, nlon_region, 'single');
non_hw_sum = zeros(nlat_region, nlon_region, 'single');
hw_count = zeros(nlat_region, nlon_region, 'single');
non_hw_count = zeros(nlat_region, nlon_region, 'single');

n_times = length(analysis_period_dates);

% 直接使用时间索引
for t_idx = 1:n_times
    % 获取当前时间点的POC异常和热浪掩码
    current_anomaly = poc_anomaly(:, :, t_idx);
    current_hw_mask = squeeze(hw_mask_npp_grid(t_idx, :, :));
    
    % 为每个网格点累加数据
    for i_lat = 1:nlat_region
        for i_lon = 1:nlon_region
            anomaly_val = current_anomaly(i_lat, i_lon);
            
            % 跳过NaN值
            if isnan(anomaly_val)
                continue;
            end
            
            if current_hw_mask(i_lat, i_lon)
                % 热浪期间
                hw_sum(i_lat, i_lon) = hw_sum(i_lat, i_lon) + anomaly_val;
                hw_count(i_lat, i_lon) = hw_count(i_lat, i_lon) + 1;
            else
                % 非热浪期间
                non_hw_sum(i_lat, i_lon) = non_hw_sum(i_lat, i_lon) + anomaly_val;
                non_hw_count(i_lat, i_lon) = non_hw_count(i_lat, i_lon) + 1;
            end
        end
    end
    
    % 更新进度
    if mod(t_idx, 100) == 0
        fprintf('已分析 %d/%d 个时间点...\n', t_idx, n_times);
    end
end

% 计算平均异常
fprintf('计算热浪期和非热浪期平均异常...\n');
mean_hw_anom = hw_sum ./ max(hw_count, 1); % 避免除以零
mean_non_hw_anom = non_hw_sum ./ max(non_hw_count, 1); % 避免除以零
diff_anom = mean_hw_anom - mean_non_hw_anom;

% 处理可能的NaN值（由于除以零）
mean_hw_anom(isnan(mean_hw_anom)) = 0;
mean_non_hw_anom(isnan(mean_non_hw_anom)) = 0;
diff_anom(isnan(diff_anom)) = 0;

% 计算热浪频率
hw_frequency = hw_count / n_times;
hw_frequency(isnan(hw_frequency)) = 0;

%% 第九步：计算四季热浪和非热浪期间POC差异
fprintf('计算四季热浪和非热浪期间POC差异...\n');

% 获取每个时间点对应的月份
date_months = month(analysis_period_dates);

% 定义季节
% 春季: 3-5月, 夏季: 6-8月, 秋季: 9-11月, 冬季: 12-2月
spring_months = [3, 4, 5];
summer_months = [6, 7, 8];
autumn_months = [9, 10, 11];
winter_months = [12, 1, 2];

% 初始化季节热浪和非热浪累加器
seasonal_hw_sum = zeros(nlat_region, nlon_region, 4, 'single');
seasonal_non_hw_sum = zeros(nlat_region, nlon_region, 4, 'single');
seasonal_hw_count = zeros(nlat_region, nlon_region, 4, 'single');
seasonal_non_hw_count = zeros(nlat_region, nlon_region, 4, 'single');

% 按季节分类数据
for t_idx = 1:n_times
    current_month = date_months(t_idx);
    current_anomaly = poc_anomaly(:, :, t_idx);
    current_hw_mask = squeeze(hw_mask_npp_grid(t_idx, :, :));
    
    % 确定季节索引
    if ismember(current_month, spring_months)
        season_idx = 2; % 春季（注意：为了与绘图顺序匹配，这里使用2）
    elseif ismember(current_month, summer_months)
        season_idx = 3; % 夏季
    elseif ismember(current_month, autumn_months)
        season_idx = 4; % 秋季
    else
        season_idx = 1; % 冬季（注意：为了与绘图顺序匹配，这里使用1）
    end
    
    % 为每个网格点累加季节数据
    for i_lat = 1:nlat_region
        for i_lon = 1:nlon_region
            anomaly_val = current_anomaly(i_lat, i_lon);
            
            % 跳过NaN值
            if isnan(anomaly_val)
                continue;
            end
            
            if current_hw_mask(i_lat, i_lon)
                % 热浪期间
                seasonal_hw_sum(i_lat, i_lon, season_idx) = seasonal_hw_sum(i_lat, i_lon, season_idx) + anomaly_val;
                seasonal_hw_count(i_lat, i_lon, season_idx) = seasonal_hw_count(i_lat, i_lon, season_idx) + 1;
            else
                % 非热浪期间
                seasonal_non_hw_sum(i_lat, i_lon, season_idx) = seasonal_non_hw_sum(i_lat, i_lon, season_idx) + anomaly_val;
                seasonal_non_hw_count(i_lat, i_lon, season_idx) = seasonal_non_hw_count(i_lat, i_lon, season_idx) + 1;
            end
        end
    end
    
    % 更新进度
    if mod(t_idx, 100) == 0
        fprintf('已分析季节数据 %d/%d 个时间点...\n', t_idx, n_times);
    end
end

% 计算四季平均异常
fprintf('计算四季平均异常...\n');
seasonal_hw_anom = zeros(nlat_region, nlon_region, 4);
seasonal_non_hw_anom = zeros(nlat_region, nlon_region, 4);
seasonal_diff_anom = zeros(nlat_region, nlon_region, 4);

for season_idx = 1:4
    % 计算热浪期平均异常
    temp_hw = seasonal_hw_sum(:, :, season_idx) ./ max(seasonal_hw_count(:, :, season_idx), 1);
    temp_hw(isnan(temp_hw)) = 0;
    seasonal_hw_anom(:, :, season_idx) = temp_hw;
    
    % 计算非热浪期平均异常
    temp_non_hw = seasonal_non_hw_sum(:, :, season_idx) ./ max(seasonal_non_hw_count(:, :, season_idx), 1);
    temp_non_hw(isnan(temp_non_hw)) = 0;
    seasonal_non_hw_anom(:, :, season_idx) = temp_non_hw;
    
    % 计算差异
    seasonal_diff_anom(:, :, season_idx) = temp_hw - temp_non_hw;
end

% 提取各季节数据（按冬季、春季、夏季、秋季顺序）
winter_hw_anom = seasonal_hw_anom(:, :, 1);
winter_non_hw_anom = seasonal_non_hw_anom(:, :, 1);
winter_diff = seasonal_diff_anom(:, :, 1);

spring_hw_anom = seasonal_hw_anom(:, :, 2);
spring_non_hw_anom = seasonal_non_hw_anom(:, :, 2);
spring_diff = seasonal_diff_anom(:, :, 2);

summer_hw_anom = seasonal_hw_anom(:, :, 3);
summer_non_hw_anom = seasonal_non_hw_anom(:, :, 3);
summer_diff = seasonal_diff_anom(:, :, 3);

autumn_hw_anom = seasonal_hw_anom(:, :, 4);
autumn_non_hw_anom = seasonal_non_hw_anom(:, :, 4);
autumn_diff = seasonal_diff_anom(:, :, 4);

%% 第十步：计算四季POC异常时间序列
fprintf('计算四季POC异常时间序列...\n');

% 计算整个区域的空间平均POC异常
spatial_mean_anomaly = zeros(n_times, 1);
for t = 1:n_times
    temp_data = poc_anomaly(:, :, t);
    spatial_mean_anomaly(t) = nanmean(temp_data(:));
end

% 按季节和年份分组计算平均异常
unique_years = unique(analysis_period_years);
n_years = length(unique_years);

% 初始化季节时间序列数据
seasonal_ts_data = struct();
seasonal_ts_data.years = unique_years;
seasonal_ts_data.winter = zeros(n_years, 1);
seasonal_ts_data.spring = zeros(n_years, 1);
seasonal_ts_data.summer = zeros(n_years, 1);
seasonal_ts_data.autumn = zeros(n_years, 1);

% 计算每年各季节的平均异常
for i = 1:n_years
    current_year = unique_years(i);
    year_mask = (analysis_period_years == current_year);
    
    % 冬季 (12-2月)
    winter_mask = year_mask & ismember(date_months, winter_months);
    if sum(winter_mask) > 0
        seasonal_ts_data.winter(i) = nanmean(spatial_mean_anomaly(winter_mask));
    else
        seasonal_ts_data.winter(i) = NaN;
    end
    
    % 春季 (3-5月)
    spring_mask = year_mask & ismember(date_months, spring_months);
    if sum(spring_mask) > 0
        seasonal_ts_data.spring(i) = nanmean(spatial_mean_anomaly(spring_mask));
    else
        seasonal_ts_data.spring(i) = NaN;
    end
    
    % 夏季 (6-8月)
    summer_mask = year_mask & ismember(date_months, summer_months);
    if sum(summer_mask) > 0
        seasonal_ts_data.summer(i) = nanmean(spatial_mean_anomaly(summer_mask));
    else
        seasonal_ts_data.summer(i) = NaN;
    end
    
    % 秋季 (9-11月)
    autumn_mask = year_mask & ismember(date_months, autumn_months);
    if sum(autumn_mask) > 0
        seasonal_ts_data.autumn(i) = nanmean(spatial_mean_anomaly(autumn_mask));
    else
        seasonal_ts_data.autumn(i) = NaN;
    end
end

%% 第十一步：生成分析图
fprintf('生成分析图...\n');

% 创建经纬度网格
[LON, LAT] = meshgrid(lon_region(1,:), lat_region(:,1));

% 设置绘图参数
font_size = 12;
title_font_size = 14;
colorbar_font_size = 11;

% 创建改进的红蓝色谱
redblue_cmap = create_redblue_cmap_improved(64);

%% 图1: 四季热浪期POC异常对比（冬季在左上角）
fig1 = figure('Position', [100, 100, 1400, 1000]);
set(fig1, 'Color', 'white', 'PaperPositionMode', 'auto');

% 冬季热浪期 - 左上角
subplot(2,2,1);
h1 = pcolor(LON, LAT, winter_hw_anom);
set(h1, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Winter', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

% 春季热浪期 - 右上角
subplot(2,2,2);
h2 = pcolor(LON, LAT, spring_hw_anom);
set(h2, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Spring', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

% 夏季热浪期 - 左下角
subplot(2,2,3);
h3 = pcolor(LON, LAT, summer_hw_anom);
set(h3, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Summer', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

% 秋季热浪期 - 右下角
subplot(2,2,4);
h4 = pcolor(LON, LAT, autumn_hw_anom);
set(h4, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Autumn', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

sgtitle('Seasonal POC Anomaly During Marine Heatwave Periods (2015-2024, 8-day average)', ...
        'FontSize', 16, 'FontWeight', 'bold');

print(fig1, fullfile(output_dir, 'Seasonal_MHW_POC.png'), '-dpng', '-r300');
saveas(fig1, fullfile(output_dir, 'Seasonal_MHW_POC.fig'));

%% 图2: 四季热浪与非热浪期POC差异
fig2 = figure('Position', [100, 100, 1400, 1000]);
set(fig2, 'Color', 'white', 'PaperPositionMode', 'auto');

% 冬季差异 - 左上角
subplot(2,2,1);
h1 = pcolor(LON, LAT, winter_diff);
set(h1, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly Difference (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Winter', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

% 春季差异 - 右上角
subplot(2,2,2);
h2 = pcolor(LON, LAT, spring_diff);
set(h2, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly Difference (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Spring', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

% 夏季差异 - 左下角
subplot(2,2,3);
h3 = pcolor(LON, LAT, summer_diff);
set(h3, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly Difference (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Summer', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

% 秋季差异 - 右下角
subplot(2,2,4);
h4 = pcolor(LON, LAT, autumn_diff);
set(h4, 'EdgeColor', 'none', 'FaceColor', 'flat');
colormap(gca, redblue_cmap);
caxis([-100, 100]);
cbar = colorbar('eastoutside');
cbar.Label.String = 'POC Anomaly Difference (mg C m^{-2} day^{-1})';
cbar.Label.FontSize = colorbar_font_size;
xlabel('Longitude (°E)', 'FontSize', font_size);
ylabel('Latitude (°N)', 'FontSize', font_size);
title('Autumn', 'FontSize', title_font_size, 'FontWeight', 'bold');
add_white_land_coastline(lon_range, lat_range);
axis equal;
xlim(lon_range);
ylim(lat_range);
set(gca, 'TickDir', 'out', 'LineWidth', 0.8, 'FontSize', font_size, 'Color', 'white');

sgtitle('Seasonal Differences in POC Anomaly Between MHW and Non-MHW Periods (2015-2024, 8-day average)', ...
        'FontSize', 16, 'FontWeight', 'bold');

print(fig2, fullfile(output_dir, 'Seasonal_Differences_POC.png'), '-dpng', '-r300');
saveas(fig2, fullfile(output_dir, 'Seasonal_Differences_POC.fig'));

%% 图3: 四季POC异常时间序列图
fig3 = figure('Position', [100, 100, 1200, 600]);
set(fig3, 'Color', 'white', 'PaperPositionMode', 'auto');

% 定义季节颜色
season_colors = [0.2 0.4 0.8;  % 冬季 - 蓝色
                 0.2 0.6 0.3;  % 春季 - 绿色
                 0.8 0.4 0.1;  % 夏季 - 橙色
                 0.7 0.5 0.2]; % 秋季 - 棕色

% 绘制时间序列
hold on;

% 冬季时间序列
winter_plot = plot(seasonal_ts_data.years, seasonal_ts_data.winter, '-o', ...
                  'Color', season_colors(1,:), 'LineWidth', 2.5, ...
                  'MarkerSize', 8, 'MarkerFaceColor', season_colors(1,:));

% 春季时间序列
spring_plot = plot(seasonal_ts_data.years, seasonal_ts_data.spring, '-s', ...
                  'Color', season_colors(2,:), 'LineWidth', 2.5, ...
                  'MarkerSize', 8, 'MarkerFaceColor', season_colors(2,:));

% 夏季时间序列
summer_plot = plot(seasonal_ts_data.years, seasonal_ts_data.summer, '-d', ...
                  'Color', season_colors(3,:), 'LineWidth', 2.5, ...
                  'MarkerSize', 8, 'MarkerFaceColor', season_colors(3,:));

% 秋季时间序列
autumn_plot = plot(seasonal_ts_data.years, seasonal_ts_data.autumn, '-^', ...
                  'Color', season_colors(4,:), 'LineWidth', 2.5, ...
                  'MarkerSize', 8, 'MarkerFaceColor', season_colors(4,:));

% 添加零线
plot([min(seasonal_ts_data.years)-0.5, max(seasonal_ts_data.years)+0.5], [0, 0], ...
     'k--', 'LineWidth', 1, 'Color', [0.5 0.5 0.5]);

% 设置图形属性
xlabel('Year', 'FontSize', font_size+1);
ylabel('POC Anomaly (mg C m^{-2} day^{-1})', 'FontSize', font_size+1);
title('Seasonal POC Anomaly Time Series (2015-2024, 8-day average)', ...
      'FontSize', title_font_size+2, 'FontWeight', 'bold');

% 设置坐标轴
xlim([min(seasonal_ts_data.years)-0.5, max(seasonal_ts_data.years)+0.5]);
% 根据数据范围设置y轴范围
y_min = min([seasonal_ts_data.winter; seasonal_ts_data.spring; ...
             seasonal_ts_data.summer; seasonal_ts_data.autumn]);
y_max = max([seasonal_ts_data.winter; seasonal_ts_data.spring; ...
             seasonal_ts_data.summer; seasonal_ts_data.autumn]);
y_range = max(abs(y_min), abs(y_max));
ylim([-y_range*1.2, y_range*1.2]);

grid on;
set(gca, 'FontSize', font_size, 'TickDir', 'out', 'LineWidth', 1.0);

% 添加图例
legend([winter_plot, spring_plot, summer_plot, autumn_plot], ...
       {'Winter', 'Spring', 'Summer', 'Autumn'}, ...
       'Location', 'best', 'FontSize', font_size, 'Box', 'off');

% 添加趋势线
% 计算各季节趋势
for i = 1:4
    switch i
        case 1
            data = seasonal_ts_data.winter;
            color = season_colors(1,:);
            season_name = 'Winter';
        case 2
            data = seasonal_ts_data.spring;
            color = season_colors(2,:);
            season_name = 'Spring';
        case 3
            data = seasonal_ts_data.summer;
            color = season_colors(3,:);
            season_name = 'Summer';
        case 4
            data = seasonal_ts_data.autumn;
            color = season_colors(4,:);
            season_name = 'Autumn';
    end
    
    % 移除NaN值
    valid_idx = ~isnan(data);
    if sum(valid_idx) > 1
        x_trend = seasonal_ts_data.years(valid_idx);
        y_trend = data(valid_idx);
        
        % 计算线性趋势
        p = polyfit(x_trend, y_trend, 1);
        trend_line = polyval(p, x_trend);
        
        % 绘制趋势线
        plot(x_trend, trend_line, '--', 'Color', color, 'LineWidth', 1.5, ...
             'DisplayName', sprintf('%s trend', season_name));
        
        % 显示趋势值
        trend_text = sprintf('%s: %.2f/yr', season_name, p(1));
        text(x_trend(end)+0.1, trend_line(end), trend_text, ...
             'FontSize', font_size-2, 'Color', color, 'VerticalAlignment', 'middle');
    end
end

% 调整布局
set(gcf, 'Position', [100, 100, 1200, 600]);

print(fig3, fullfile(output_dir, 'Seasonal_Time_Series_POC.png'), '-dpng', '-r300');
saveas(fig3, fullfile(output_dir, 'Seasonal_Time_Series_POC.fig'));

%% 图4: 月度POC异常时间序列（可选）
fig4 = figure('Position', [100, 100, 1400, 600]);
set(fig4, 'Color', 'white', 'PaperPositionMode', 'auto');

% 创建月度时间序列
monthly_anomaly = zeros(length(analysis_period_dates), 1);
for t = 1:length(analysis_period_dates)
    temp_data = poc_anomaly(:, :, t);
    monthly_anomaly(t) = nanmean(temp_data(:));
end

% 绘制月度时间序列
subplot(2,1,1);
plot(analysis_period_dates, monthly_anomaly, 'b-', 'LineWidth', 1.5);
hold on;

% 添加热浪期的标记
hw_periods = any(hw_mask_npp_grid, [2, 3]); % 判断每个时间点是否有热浪
hw_dates = analysis_period_dates(hw_periods);
hw_values = monthly_anomaly(hw_periods);

scatter(hw_dates, hw_values, 30, 'r', 'filled', 'MarkerFaceAlpha', 0.6);

% 添加移动平均
window_size = 30; % 约240天（30*8天）
if length(monthly_anomaly) > window_size
    moving_avg = movmean(monthly_anomaly, window_size);
    plot(analysis_period_dates, moving_avg, 'k-', 'LineWidth', 2.5, ...
         'DisplayName', sprintf('%d-point moving average', window_size));
end

xlabel('Date', 'FontSize', font_size);
ylabel('POC Anomaly (mg C m^{-2} day^{-1})', 'FontSize', font_size);
title('Monthly POC Anomaly Time Series with MHW Events (2015-2024, 8-day average)', ...
      'FontSize', title_font_size, 'FontWeight', 'bold');
legend({'POC Anomaly', 'MHW Events', 'Moving Average'}, 'Location', 'best', 'FontSize', font_size-1);
grid on;
set(gca, 'FontSize', font_size-1, 'TickDir', 'out');

% 添加年度平均子图
subplot(2,1,2);
annual_mean = zeros(length(unique_years), 1);
annual_std = zeros(length(unique_years), 1);

for i = 1:length(unique_years)
    year = unique_years(i);
    year_mask = (analysis_period_years == year);
    annual_mean(i) = nanmean(monthly_anomaly(year_mask));
    annual_std(i) = nanstd(monthly_anomaly(year_mask));
end

bar(unique_years, annual_mean, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k', 'LineWidth', 1);
hold on;
errorbar(unique_years, annual_mean, annual_std, 'k.', 'LineWidth', 1.5);
plot(unique_years, zeros(size(unique_years)), 'k--', 'LineWidth', 1);

xlabel('Year', 'FontSize', font_size);
ylabel('Annual Mean POC Anomaly (mg C m^{-2} day^{-1})', 'FontSize', font_size);
title('Annual Mean POC Anomaly with Standard Deviation', ...
      'FontSize', title_font_size, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', font_size-1, 'TickDir', 'out', 'XTick', unique_years);

% 在柱子上添加数值标签
for i = 1:length(unique_years)
    text(unique_years(i), annual_mean(i) + sign(annual_mean(i))*annual_std(i)*0.5, ...
         sprintf('%.1f', annual_mean(i)), 'HorizontalAlignment', 'center', ...
         'FontSize', font_size-2, 'FontWeight', 'bold');
end

print(fig4, fullfile(output_dir, 'Monthly_Time_Series_POC.png'), '-dpng', '-r300');
saveas(fig4, fullfile(output_dir, 'Monthly_Time_Series_POC.fig'));

%% 第十二步：保存结果
fprintf('保存分析结果...\n');

% 保存空间分布数据
spatial_data.lon = lon_region(1,:);
spatial_data.lat = lat_region(:,1);
spatial_data.mean_hw_anom = mean_hw_anom;
spatial_data.mean_non_hw_anom = mean_non_hw_anom;
spatial_data.diff_anom = diff_anom;
spatial_data.hw_frequency = hw_frequency;

% 保存季节数据
seasonal_data.winter_hw_anom = winter_hw_anom;
seasonal_data.spring_hw_anom = spring_hw_anom;
seasonal_data.summer_hw_anom = summer_hw_anom;
seasonal_data.autumn_hw_anom = autumn_hw_anom;
seasonal_data.winter_diff = winter_diff;
seasonal_data.spring_diff = spring_diff;
seasonal_data.summer_diff = summer_diff;
seasonal_data.autumn_diff = autumn_diff;

% 保存季节统计
seasonal_stats.winter_mean = nanmean(winter_diff(:));
seasonal_stats.spring_mean = nanmean(spring_diff(:));
seasonal_stats.summer_mean = nanmean(summer_diff(:));
seasonal_stats.autumn_mean = nanmean(autumn_diff(:));
seasonal_stats.winter_std = nanstd(winter_diff(:));
seasonal_stats.spring_std = nanstd(spring_diff(:));
seasonal_stats.summer_std = nanstd(summer_diff(:));
seasonal_stats.autumn_std = nanstd(autumn_diff(:));

% 保存时间序列数据
time_series_data = seasonal_ts_data;
time_series_data.dates = analysis_period_dates;
time_series_data.monthly_anomaly = monthly_anomaly;

save(fullfile(output_dir, 'poc_analysis_data.mat'), 'spatial_data', 'seasonal_data', ...
     'seasonal_stats', 'time_series_data');

fprintf('分析完成！所有结果已保存到目录: %s\n', output_dir);
fprintf('生成的分析图:\n');
fprintf('  Seasonal_MHW_POC.png: 四季热浪期POC异常对比\n');
fprintf('  Seasonal_Differences_POC.png: 四季热浪与非热浪期POC差异\n');
fprintf('  Seasonal_Time_Series_POC.png: 四季POC异常时间序列图\n');
fprintf('  Monthly_Time_Series_POC.png: 月度POC异常时间序列图\n');

%% 辅助函数定义
function cmap = create_redblue_cmap_improved(n)
    % 创建改进的红蓝色谱，确保0值为白色
    if nargin < 1
        n = 64;
    end
    
    % 确保n是偶数
    if mod(n, 2) ~= 0
        n = n + 1;
    end
    
    half = n/2;
    cmap = zeros(n, 3);
    
    % 蓝色部分 (从深蓝到白色)
    for i = 1:half
        ratio = (i-1)/(half-1);
        if ratio < 0.7
            blue_ratio = ratio/0.7;
            cmap(i, 1) = 0.0 * (1-blue_ratio) + 0.7 * blue_ratio;
            cmap(i, 2) = 0.0 * (1-blue_ratio) + 0.7 * blue_ratio;
            cmap(i, 3) = 0.5 * (1-blue_ratio) + 1.0 * blue_ratio;
        else
            white_ratio = (ratio-0.7)/0.3;
            cmap(i, 1) = 0.7 * (1-white_ratio) + 1.0 * white_ratio;
            cmap(i, 2) = 0.7 * (1-white_ratio) + 1.0 * white_ratio;
            cmap(i, 3) = 1.0;
        end
    end
    
    % 红色部分 (从白色到深红)
    for i = (half+1):n
        ratio = (i-half-1)/(half-1);
        if ratio < 0.3
            red_ratio = ratio/0.3;
            cmap(i, 1) = 1.0;
            cmap(i, 2) = 1.0 * (1-red_ratio) + 0.7 * red_ratio;
            cmap(i, 3) = 1.0 * (1-red_ratio) + 0.7 * red_ratio;
        else
            dark_ratio = (ratio-0.3)/0.7;
            cmap(i, 1) = 1.0 * (1-dark_ratio) + 0.5 * dark_ratio;
            cmap(i, 2) = 0.7 * (1-dark_ratio) + 0.0 * dark_ratio;
            cmap(i, 3) = 0.7 * (1-dark_ratio) + 0.0 * dark_ratio;
        end
    end
end

function add_white_land_coastline(lon_range, lat_range)
    % 添加白色陆地海岸线
    hold on;
    
    % 首先绘制区域边界
    plot([lon_range(1) lon_range(2) lon_range(2) lon_range(1) lon_range(1)], ...
         [lat_range(1) lat_range(1) lat_range(2) lat_range(2) lat_range(1)], ...
         'k-', 'LineWidth', 1.5, 'Color', [0.2 0.2 0.2]);
    
    % 尝试加载和绘制海岸线
    try
        % 检查海岸线数据是否已加载
        if ~exist('coastlon', 'var') || ~exist('coastlat', 'var')
            if exist('coastlines.mat', 'file')
                coast_data = load('coastlines.mat');
                coastlon = coast_data.coastlon;
                coastlat = coast_data.coastlat;
            else
                % 如果找不到coastlines.mat，创建一个简单的海岸线
                fprintf('Using simple coastline approximation\n');
                return;
            end
        end
        
        if exist('coastlon', 'var') && exist('coastlat', 'var')
            % 创建海岸线的副本进行处理
            coastlon_clean = coastlon;
            coastlat_clean = coastlat;
            
            % 找出大的跳跃（可能表示跨区域连接）
            dx = [0; diff(coastlon)];
            dy = [0; diff(coastlat)];
            large_jumps = (abs(dx) > 10) | (abs(dy) > 10);
            
            % 在大跳跃处插入NaN以断开线条
            coastlon_clean(large_jumps) = NaN;
            coastlat_clean(large_jumps) = NaN;
            
            % 绘制海岸线 - 使用黑色线条
            plot(coastlon_clean, coastlat_clean, ...
                 'k-', 'LineWidth', 1.0, 'Color', [0.3 0.3 0.3]);
        end
        
    catch ME
        % 如果海岸线绘制失败，只保留边界框
        fprintf('Coastline plotting failed, using boundary only: %s\n', ME.message);
    end
end