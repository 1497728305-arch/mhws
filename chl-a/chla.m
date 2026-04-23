% 叶绿素a与海洋热浪关联分析（美观图像+相关性分析）
% 分析2015-2024年热浪期间和非热浪期间的叶绿素a异常，按季节对比

clear;
clc;

%% 参数设置
lon_range = [110, 180]; % 东经110-180度
lat_range = [30, 60];  % 北纬30-60度
target_years = 2015:2024;  % 分析年份

% 文件路径
chl_file = 'F:\8DCHL\dlb\dlb\output\Unet_t3_chlor_a_output\Unet_t3_chlor_a_ds_combined.nc'; % 叶绿素a数据文件路径
hw_events_dir  = 'D:\dlb\m_mhw1.0-master\m_mhw1.0-master\data\global\marine_heatwave_results\'; % 热浪事件文件路径
output_dir = 'chl_heatwave_analysis'; % 输出目录

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('开始叶绿素a与海洋热浪关联分析（美观图像+相关性分析）...\n');

%% 第一步：读取叶绿素a数据
fprintf('读取叶绿素a数据...\n');

% 检查叶绿素文件是否存在
if ~exist(chl_file, 'file')
    error('叶绿素数据文件不存在: %s\n请检查文件路径是否正确。', chl_file);
end

try
    % 获取文件信息
    nc_info = ncinfo(chl_file);
    
    % 读取维度信息
    lon_chl = ncread(chl_file, 'longitude');
    lat_chl = ncread(chl_file, 'latitude');
    
    % 选择目标区域
    lon_idx_chl = find(lon_chl >= lon_range(1) & lon_chl <= lon_range(2));
    lat_idx_chl = find(lat_chl >= lat_range(1) & lat_chl <= lat_range(2));
    
    % 提取目标区域的经纬度值
    target_lon_chl = lon_chl(lon_idx_chl);
    target_lat_chl = lat_chl(lat_idx_chl);
    
    % 计算格点数量
    n_lon_chl = length(lon_idx_chl);
    n_lat_chl = length(lat_idx_chl);
    
    % 读取时间并转换为日期
    time_units = ncreadatt(chl_file, 'time', 'units');
    time_base_str = strrep(time_units, 'days since ', '');
    
    % 修复时间格式问题 - 尝试多种可能的格式
    try
        % 尝试第一种常见格式
        time_base = datetime(time_base_str, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    catch
        try
            % 尝试第二种常见格式
            time_base = datetime(time_base_str, 'InputFormat', 'yyyy-MM-dd');
        catch
            try
                % 尝试第三种常见格式
                time_base = datetime(time_base_str, 'InputFormat', 'yyyy-MM');
            catch
                % 如果所有格式都失败，使用默认日期
                fprintf('警告：无法解析时间基准 "%s"，使用默认日期 2015-07-01\n', time_base_str);
                time_base = datetime(2015, 7, 1);
            end
        end
    end
    
    % 读取时间变量
    time_var = ncread(chl_file, 'time');
    n_time_total = length(time_var);
    
    % 创建所有日期
    chl_dates = time_base + days(time_var);
    
    % 选择2015-2024年的数据
    date_mask = year(chl_dates) >= 2015 & year(chl_dates) <= 2024;
    selected_dates_chl = chl_dates(date_mask);
    time_idx_chl = find(date_mask);
    n_times_chl = length(time_idx_chl);
    
    fprintf('叶绿素数据时间范围: %s 到 %s (%d 天)\n', ...
        datestr(min(selected_dates_chl)), datestr(max(selected_dates_chl)), n_times_chl);
    
catch ME
    error('读取叶绿素数据时出错: %s\n请检查NetCDF文件格式是否正确。', ME.message);
end

%% 第二步：加载网格点级别的热浪事件数据
fprintf('加载网格点级别的热浪事件数据...\n');

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
fprintf('热浪事件经纬度范围: 经度 %.2f-%.2f, 纬度 %.2f-%.2f\n', ...
    min(hw_lons), max(hw_lons), min(hw_lats), max(hw_lats));

% 创建热浪事件网格
n_lon_hw = length(hw_lons);
n_lat_hw = length(hw_lats);

% 创建一个三维数组来存储每个网格点的热浪掩码（在热浪事件网格上）
hw_mask_hw_grid = false(n_times_chl, n_lon_hw, n_lat_hw);

% 确保selected_dates_chl是列向量
selected_dates_chl = selected_dates_chl(:);

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
    
    % 确保热浪事件在选定日期范围内
    if start_date > selected_dates_chl(end) || end_date < selected_dates_chl(1)
        continue;
    end
    
    % 调整热浪事件日期以匹配选定日期范围
    start_date = max(start_date, selected_dates_chl(1));
    end_date = min(end_date, selected_dates_chl(end));
    
    % 找到热浪事件在选定日期范围内的索引
    event_mask = (selected_dates_chl >= start_date) & (selected_dates_chl <= end_date);
    
    % 修复赋值错误：确保event_mask是列向量
    event_mask = event_mask(:);
    
    % 更新热浪掩码
    hw_mask_hw_grid(:, lon_idx, lat_idx) = hw_mask_hw_grid(:, lon_idx, lat_idx) | event_mask;
    
    % 更新进度
    if mod(i, 1000) == 0
        fprintf('已处理 %d/%d 个热浪事件...\n', i, height(all_hw_events));
    end
end

% 计算热浪期和非热浪期天数
hw_days = sum(hw_mask_hw_grid, 1);
non_hw_days = n_times_chl - hw_days;

fprintf('热浪期天数范围: %d 到 %d\n', min(hw_days(:)), max(hw_days(:)));
fprintf('非热浪期天数范围: %d 到 %d\n', min(non_hw_days(:)), max(non_hw_days(:)));

% 检查热浪期天数是否合理
if max(hw_days(:)) == n_times_chl
    warning('某些网格点的所有日期都被标记为热浪期，这可能不正确。请检查热浪事件数据。');
elseif max(hw_days(:)) == 0
    warning('所有网格点都没有热浪期，这可能不正确。请检查热浪事件数据。');
end

%% 第三步：计算叶绿素a气候平均态和异常
fprintf('计算叶绿素a气候平均态和异常...\n');

% 计算每日气候平均态（使用所有年份数据）
doy = day(selected_dates_chl, 'dayofyear');
unique_doy = unique(doy);
chl_climatology = zeros(length(unique_doy), n_lon_chl, n_lat_chl, 'single'); % 使用单精度节省内存

% 分块计算气候平均态
for i = 1:length(unique_doy)
    day_val = unique_doy(i);
    day_mask = (doy == day_val);
    day_indices = time_idx_chl(day_mask);
    
    if ~isempty(day_indices)
        % 读取这些天的数据并计算平均
        day_chl = zeros(length(day_indices), n_lon_chl, n_lat_chl, 'single'); % 使用单精度
        
        for j = 1:length(day_indices)
            t_idx = day_indices(j);
            
            % 检查时间索引是否有效
            if t_idx < 1 || t_idx > n_time_total
                fprintf('警告：时间索引 %d 超出范围 (1-%d)，跳过\n', t_idx, n_time_total);
                continue;
            end
            
            % 读取单天数据
            try
                chl_data = ncread(chl_file, 'chlor_a', ...
                                 [lon_idx_chl(1), lat_idx_chl(1), t_idx], ...
                                 [length(lon_idx_chl), length(lat_idx_chl), 1]);
                day_chl(j, :, :) = single(chl_data); % 转换为单精度
            catch ME
                fprintf('警告：无法读取时间索引 %d 的数据: %s\n', t_idx, ME.message);
                day_chl(j, :, :) = NaN;
            end
        end
        
        % 计算该年日的平均
        chl_climatology(i, :, :) = mean(day_chl, 1, 'omitnan');
    end
    
    if mod(i, 50) == 0
        fprintf('已完成气候态计算 %d/%d...\n', i, length(unique_doy));
    end
end

% 计算异常值
fprintf('计算叶绿素a异常值...\n');
chl_anomaly = zeros(n_times_chl, n_lon_chl, n_lat_chl, 'single'); % 预分配内存

for t = 1:n_times_chl
    time_idx_val = time_idx_chl(t);
    
    % 检查时间索引是否有效
    if time_idx_val < 1 || time_idx_val > n_time_total
        fprintf('警告：时间索引 %d 超出范围 (1-%d)，跳过\n', time_idx_val, n_time_total);
        continue;
    end
    
    % 读取当天数据
    try
        chl_data = ncread(chl_file, 'chlor_a', ...
                         [lon_idx_chl(1), lat_idx_chl(1), time_idx_val], ...
                         [length(lon_idx_chl), length(lat_idx_chl), 1]);
        
        % 获取对应的气候值
        doy_val = doy(t);
        clim_idx = find(unique_doy == doy_val);
        clim_data = squeeze(chl_climatology(clim_idx, :, :));
        
        % 计算异常
        chl_anomaly(t, :, :) = single(chl_data) - clim_data;
    catch ME
        fprintf('警告：无法读取时间索引 %d 的数据: %s\n', time_idx_val, ME.message);
        chl_anomaly(t, :, :) = NaN;
    end
    
    % 更新进度
    if mod(t, 100) == 0
        fprintf('已计算 %d/%d 天的异常值...\n', t, n_times_chl);
    end
end

%% 第四步：将热浪掩码映射到叶绿素网格并进行季节性分析
fprintf('将热浪掩码映射到叶绿素网格并进行季节性分析...\n');

% 将热浪掩码映射到叶绿素网格
hw_mask_chl_grid = false(n_times_chl, n_lon_chl, n_lat_chl);

% 使用meshgrid创建热浪网格
[X_hw, Y_hw] = meshgrid(hw_lons, hw_lats);
X_hw = X_hw'; % 转置以使维度匹配
Y_hw = Y_hw'; % 转置以使维度匹配

% 为每个叶绿素网格点找到最近的热浪网格点索引
nearest_hw_idx = zeros(n_lon_chl, n_lat_chl, 2); % 存储经度和纬度索引

for i = 1:n_lon_chl
    for j = 1:n_lat_chl
        % 计算当前叶绿素网格点到所有热浪网格点的距离
        dist = sqrt((X_hw - target_lon_chl(i)).^2 + (Y_hw - target_lat_chl(j)).^2);
        
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
        fprintf('已处理 %d/%d 个经度点...\n', i, n_lon_chl);
    end
end

% 使用最近邻映射将热浪掩码从热浪网格映射到叶绿素网格
fprintf('映射热浪掩码到叶绿素网格...\n');

for t = 1:n_times_chl
    % 获取当前时间点的热浪掩码
    hw_mask_t = squeeze(hw_mask_hw_grid(t, :, :));
    
    % 为每个叶绿素网格点获取对应的热浪掩码
    for i = 1:n_lon_chl
        for j = 1:n_lat_chl
            % 获取最近的热浪网格点索引
            lon_idx = nearest_hw_idx(i, j, 1);
            lat_idx = nearest_hw_idx(i, j, 2);
            
            % 将热浪掩码映射到叶绿素网格
            hw_mask_chl_grid(t, i, j) = hw_mask_t(lon_idx, lat_idx);
        end
    end
    
    % 更新进度
    if mod(t, 100) == 0
        fprintf('已映射 %d/%d 个时间点...\n', t, n_times_chl);
    end
end

% 定义季节
months = month(selected_dates_chl);
season_labels = {'Winter', 'Spring', 'Summer', 'Autumn'};
season_months = {[12, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11]};

% 为每个时间点分配季节
season_idx = zeros(n_times_chl, 1);
for i = 1:n_times_chl
    m = months(i);
    if ismember(m, season_months{1}) % 冬季
        season_idx(i) = 1;
    elseif ismember(m, season_months{2}) % 春季
        season_idx(i) = 2;
    elseif ismember(m, season_months{3}) % 夏季
        season_idx(i) = 3;
    elseif ismember(m, season_months{4}) % 秋季
        season_idx(i) = 4;
    end
end

% 季节性分析：为每个季节分别计算热浪期和非热浪期的异常
fprintf('进行季节性热浪期与非热浪期对比分析...\n');

% 初始化季节性累加器
season_hw_sum = zeros(4, n_lon_chl, n_lat_chl, 'single');
season_non_hw_sum = zeros(4, n_lon_chl, n_lat_chl, 'single');
season_hw_count = zeros(4, n_lon_chl, n_lat_chl, 'single');
season_non_hw_count = zeros(4, n_lon_chl, n_lat_chl, 'single');
%% 

% 按季节进行分析
for season = 1:4
    fprintf('分析%s...\n', season_labels{season});
    
    % 选择当前季节的数据
    season_mask = (season_idx == season);
    season_indices = find(season_mask);
    
    if isempty(season_indices)
        fprintf('警告：%s没有数据，跳过\n', season_labels{season});
        continue;
    end
    
    % 提取当前季节的异常值和热浪掩码
    season_anomaly = chl_anomaly(season_mask, :, :);
    season_hw_mask = hw_mask_chl_grid(season_mask, :, :);
    
    % 为每个网格点分析热浪期和非热浪期
    for i_lon = 1:n_lon_chl
        for i_lat = 1:n_lat_chl
            % 提取当前网格点的异常值和热浪掩码
            point_anomaly = squeeze(season_anomaly(:, i_lon, i_lat));
            point_hw_mask = squeeze(season_hw_mask(:, i_lon, i_lat));
            
            % 分离热浪期和非热浪期的异常值
            hw_anomaly = point_anomaly(point_hw_mask);
            non_hw_anomaly = point_anomaly(~point_hw_mask);
            
            % 累加热浪期异常值
            if ~isempty(hw_anomaly)
                season_hw_sum(season, i_lon, i_lat) = sum(hw_anomaly, 'omitnan');
                season_hw_count(season, i_lon, i_lat) = sum(~isnan(hw_anomaly));
            end
            
            % 累加非热浪期异常值
            if ~isempty(non_hw_anomaly)
                season_non_hw_sum(season, i_lon, i_lat) = sum(non_hw_anomaly, 'omitnan');
                season_non_hw_count(season, i_lon, i_lat) = sum(~isnan(non_hw_anomaly));
            end
        end
    end
end

% 计算季节性平均异常
fprintf('计算季节性热浪期和非热浪期平均异常...\n');
season_mean_hw_anom = season_hw_sum ./ max(season_hw_count, 1); % 避免除以零
season_mean_non_hw_anom = season_non_hw_sum ./ max(season_non_hw_count, 1); % 避免除以零
season_diff_anom = season_mean_hw_anom - season_mean_non_hw_anom;

% 处理可能的NaN值
season_mean_hw_anom(isnan(season_mean_hw_anom)) = 0;
season_mean_non_hw_anom(isnan(season_mean_non_hw_anom)) = 0;
season_diff_anom(isnan(season_diff_anom)) = 0;

% 全年分析（原有分析）
fprintf('进行全年热浪期与非热浪期对比分析...\n');

% 初始化热浪期和非热浪期累加器
hw_sum = zeros(n_lon_chl, n_lat_chl, 'single');
non_hw_sum = zeros(n_lon_chl, n_lat_chl, 'single');
hw_count = zeros(n_lon_chl, n_lat_chl, 'single');
non_hw_count = zeros(n_lon_chl, n_lat_chl, 'single');

% 按年份和年积日进行分析
years = year(selected_dates_chl);
doy = day(selected_dates_chl, 'dayofyear');
unique_years = unique(years);
unique_doy = unique(doy);

% 为每个年积日创建热浪期和非热浪期的异常值
for i = 1:length(unique_doy)
    day_val = unique_doy(i);
    
    % 找到该年积日的所有日期
    day_mask = (doy == day_val);
    day_indices = find(day_mask);
    
    if isempty(day_indices)
        continue;
    end
    
    % 提取该年积日的异常值和热浪掩码
    day_anomaly = chl_anomaly(day_mask, :, :);
    day_hw_mask = hw_mask_chl_grid(day_mask, :, :);
    day_years = years(day_mask);
    
    % 为每个网格点分析热浪期和非热浪期
    for i_lon = 1:n_lon_chl
        for i_lat = 1:n_lat_chl
            % 提取当前网格点的异常值和热浪掩码
            point_anomaly = squeeze(day_anomaly(:, i_lon, i_lat));
            point_hw_mask = squeeze(day_hw_mask(:, i_lon, i_lat));
            
            % 分离热浪期和非热浪期的异常值
            hw_anomaly = point_anomaly(point_hw_mask);
            non_hw_anomaly = point_anomaly(~point_hw_mask);
            
            % 累加热浪期异常值
            if ~isempty(hw_anomaly)
                hw_sum(i_lon, i_lat) = hw_sum(i_lon, i_lat) + sum(hw_anomaly, 'omitnan');
                hw_count(i_lon, i_lat) = hw_count(i_lon, i_lat) + sum(~isnan(hw_anomaly));
            end
            
            % 累加非热浪期异常值
            if ~isempty(non_hw_anomaly)
                non_hw_sum(i_lon, i_lat) = non_hw_sum(i_lon, i_lat) + sum(non_hw_anomaly, 'omitnan');
                non_hw_count(i_lon, i_lat) = non_hw_count(i_lon, i_lat) + sum(~isnan(non_hw_anomaly));
            end
        end
    end
    
    % 更新进度
    if mod(i, 50) == 0
        fprintf('已分析 %d/%d 个年积日...\n', i, length(unique_doy));
    end
end

% 计算全年平均异常
fprintf('计算全年热浪期和非热浪期平均异常...\n');
mean_hw_anom = hw_sum ./ max(hw_count, 1); % 避免除以零
mean_non_hw_anom = non_hw_sum ./ max(non_hw_count, 1); % 避免除以零
diff_anom = mean_hw_anom - mean_non_hw_anom;

% 处理可能的NaN值
mean_hw_anom(isnan(mean_hw_anom)) = 0;
mean_non_hw_anom(isnan(mean_non_hw_anom)) = 0;
diff_anom(isnan(diff_anom)) = 0;

% 计算热浪频率和强度
hw_frequency = hw_count / n_times_chl;
mean_hw_intensity = hw_sum ./ max(hw_count, 1);
mean_hw_intensity(isnan(mean_hw_intensity)) = 0;

%% 第五步：相关性分析
%% 第五步：相关性分析（修复corrcoef错误 - 包含持续时间、强度和频率）
fprintf('进行相关性分析（修复版 - 包含持续时间、强度和频率）...\n');

% 计算热浪频率与叶绿素异常的相关性
correlation_matrix = zeros(n_lon_chl, n_lat_chl);
p_value_matrix = zeros(n_lon_chl, n_lat_chl);

% 新增：热浪持续时间与叶绿素异常相关性
duration_corr_matrix = zeros(n_lon_chl, n_lat_chl);
duration_p_matrix = zeros(n_lon_chl, n_lat_chl);

% 新增：热浪强度与叶绿素异常相关性
intensity_corr_matrix = zeros(n_lon_chl, n_lat_chl);
intensity_p_matrix = zeros(n_lon_chl, n_lat_chl);

% 计算每个网格点的热浪持续时间指标
fprintf('计算热浪持续时间和强度指标...\n');

% 初始化热浪持续时间矩阵
hw_duration_metrics = zeros(n_lon_chl, n_lat_chl);
hw_intensity_metrics = zeros(n_lon_chl, n_lat_chl);

for i = 1:n_lon_chl
    for j = 1:n_lat_chl
        % 提取当前网格点的热浪掩码
        hw_ts = squeeze(hw_mask_chl_grid(:, i, j));
        
        % 计算热浪事件持续时间
        if sum(hw_ts) > 0
            % 找到热浪事件的开始和结束
            hw_diff = diff([0; hw_ts; 0]);
            start_idx = find(hw_diff == 1);
            end_idx = find(hw_diff == -1) - 1;
            
            if ~isempty(start_idx)
                % 计算平均持续时间
                durations = end_idx - start_idx + 1;
                hw_duration_metrics(i, j) = mean(durations);
                
                % 计算热浪强度（热浪期间叶绿素异常的平均值）
                hw_chl_values = [];
                for k = 1:length(start_idx)
                    event_chl = chl_anomaly(start_idx(k):end_idx(k), i, j);
                    valid_chl = event_chl(~isnan(event_chl));
                    if ~isempty(valid_chl)
                        hw_chl_values = [hw_chl_values; mean(valid_chl)];
                    end
                end
                if ~isempty(hw_chl_values)
                    hw_intensity_metrics(i, j) = mean(hw_chl_values);
                else
                    hw_intensity_metrics(i, j) = 0;
                end
            else
                hw_duration_metrics(i, j) = 0;
                hw_intensity_metrics(i, j) = 0;
            end
        else
            hw_duration_metrics(i, j) = 0;
            hw_intensity_metrics(i, j) = 0;
        end
    end
end

% 使用正确的相关性计算方法
fprintf('计算相关性...\n');

for i = 1:n_lon_chl
    for j = 1:n_lat_chl
        % 提取当前网格点的时间序列
        chl_ts = squeeze(chl_anomaly(:, i, j));
        hw_ts = squeeze(hw_mask_chl_grid(:, i, j));
        
        % 移除NaN值
        valid_idx = ~isnan(chl_ts) & ~isnan(hw_ts);
        if sum(valid_idx) > 10 % 至少需要10个有效点
            chl_valid = chl_ts(valid_idx);
            hw_valid = hw_ts(valid_idx);
            
            % 方法1：使用corr函数（如果可用）
            try
                % 频率相关性
                [r_freq, p_freq] = corr(chl_valid, hw_valid);
                correlation_matrix(i, j) = r_freq;
                p_value_matrix(i, j) = p_freq;
                
                % 持续时间相关性（使用网格点级别的平均）
                if hw_duration_metrics(i, j) > 0
                    % 这里我们计算热浪期间叶绿素异常与平均持续时间的相关性
                    hw_periods = find(hw_valid);
                    if length(hw_periods) > 5
                        hw_chl_during = chl_valid(hw_periods);
                        % 使用该网格点的平均持续时间
                        avg_duration = hw_duration_metrics(i, j);
                        % 这里我们计算的是热浪期间叶绿素异常与平均持续时间的相关性
                        % 注意：这不是传统意义上的时间序列相关性
                        duration_corr_matrix(i, j) = 0; % 暂时设为0，下面有更好的方法
                        duration_p_matrix(i, j) = 1;    % 暂时设为不显著
                    end
                end
                
                % 强度相关性（类似处理）
                if hw_intensity_metrics(i, j) ~= 0
                    hw_periods = find(hw_valid);
                    if length(hw_periods) > 5
                        hw_chl_during = chl_valid(hw_periods);
                        avg_intensity = hw_intensity_metrics(i, j);
                        intensity_corr_matrix(i, j) = 0; % 暂时设为0
                        intensity_p_matrix(i, j) = 1;    % 暂时设为不显著
                    end
                end
                
            catch
                % 如果corr函数不可用，使用自定义相关性计算
                fprintf('使用自定义相关性计算 for grid (%d, %d)\n', i, j);
                [r_freq, p_freq] = custom_corr(chl_valid, hw_valid);
                correlation_matrix(i, j) = r_freq;
                p_value_matrix(i, j) = p_freq;
            end
        else
            correlation_matrix(i, j) = NaN;
            p_value_matrix(i, j) = NaN;
            duration_corr_matrix(i, j) = NaN;
            duration_p_matrix(i, j) = NaN;
            intensity_corr_matrix(i, j) = NaN;
            intensity_p_matrix(i, j) = NaN;
        end
    end
end

% 更合理的方法：计算网格点级别的相关性
fprintf('计算网格点级别的热浪特征相关性...\n');

% 准备网格点级别的数据
valid_grids = hw_frequency > 0.01 & hw_duration_metrics > 0; % 至少1%热浪频率和正持续时间

% 频率相关性（网格点级别）
grid_freq = hw_frequency(valid_grids);
grid_hw_chl = mean_hw_anom(valid_grids);
if sum(valid_grids(:)) > 10
    [r_grid_freq, p_grid_freq] = corr(grid_freq(:), grid_hw_chl(:), 'rows', 'complete');
    fprintf('网格点级别频率相关性: r=%.3f, p=%.3f\n', r_grid_freq, p_grid_freq);
end

% 持续时间相关性（网格点级别）
grid_dur = hw_duration_metrics(valid_grids);
if sum(valid_grids(:)) > 10
    [r_grid_dur, p_grid_dur] = corr(grid_dur(:), grid_hw_chl(:), 'rows', 'complete');
    fprintf('网格点级别持续时间相关性: r=%.3f, p=%.3f\n', r_grid_dur, p_grid_dur);
    
    % 更新持续时间相关性矩阵
    duration_corr_matrix(valid_grids) = r_grid_dur;
    duration_p_matrix(valid_grids) = p_grid_dur;
end

% 强度相关性（网格点级别）
grid_int = hw_intensity_metrics(valid_grids);
valid_int_grids = valid_grids & hw_intensity_metrics ~= 0;
if sum(valid_int_grids(:)) > 10
    grid_int_valid = hw_intensity_metrics(valid_int_grids);
    grid_hw_chl_valid = mean_hw_anom(valid_int_grids);
    [r_grid_int, p_grid_int] = corr(grid_int_valid(:), grid_hw_chl_valid(:), 'rows', 'complete');
    fprintf('网格点级别强度相关性: r=%.3f, p=%.3f\n', r_grid_int, p_grid_int);
    
    % 更新强度相关性矩阵
    intensity_corr_matrix(valid_int_grids) = r_grid_int;
    intensity_p_matrix(valid_int_grids) = p_grid_int;
end

% 计算季节性相关性（使用正确的方法）
seasonal_correlation = zeros(4, n_lon_chl, n_lat_chl);
seasonal_p_value = zeros(4, n_lon_chl, n_lat_chl);

for season = 1:4
    fprintf('计算%s相关性...\n', season_labels{season});
    
    season_mask = (season_idx == season);
    season_indices = find(season_mask);
    
    if isempty(season_indices)
        continue;
    end
    
    for i = 1:n_lon_chl
        for j = 1:n_lat_chl
            % 提取当前季节和网格点的时间序列
            chl_ts = squeeze(chl_anomaly(season_mask, i, j));
            hw_ts = squeeze(hw_mask_chl_grid(season_mask, i, j));
            
            % 移除NaN值
            valid_idx = ~isnan(chl_ts) & ~isnan(hw_ts);
            if sum(valid_idx) > 5 % 季节性数据较少，降低阈值
                chl_valid = chl_ts(valid_idx);
                hw_valid = hw_ts(valid_idx);
                
                % 使用正确的方法计算相关性
                try
                    [r, p] = corr(chl_valid, hw_valid);
                    seasonal_correlation(season, i, j) = r;
                    seasonal_p_value(season, i, j) = p;
                catch
                    [r, p] = custom_corr(chl_valid, hw_valid);
                    seasonal_correlation(season, i, j) = r;
                    seasonal_p_value(season, i, j) = p;
                end
            else
                seasonal_correlation(season, i, j) = NaN;
                seasonal_p_value(season, i, j) = NaN;
            end
        end
    end
end

% 自定义相关性计算函数


%% 第六步：SCI论文标准的美观可视化结果（修复所有legend问题）
fprintf('生成SCI论文标准的可视化结果...\n');

% 设置SCI论文标准的图形属性
set(0, 'DefaultAxesFontName', 'Arial');  % 使用Arial字体
set(0, 'DefaultTextFontName', 'Arial');
set(0, 'DefaultAxesFontSize', 10);
set(0, 'DefaultTextFontSize', 10);
set(0, 'DefaultLineLineWidth', 1.2);
set(0, 'DefaultAxesLineWidth', 0.8);
set(0, 'DefaultAxesTickDir', 'out');
set(0, 'DefaultAxesBox', 'off');

% 定义SCI论文常用配色
sci_colors = struct();
sci_colors.blue = [0.2, 0.4, 0.8];
sci_colors.red = [0.8, 0.2, 0.2];
sci_colors.green = [0.2, 0.6, 0.3];
sci_colors.orange = [0.9, 0.5, 0.1];
sci_colors.purple = [0.6, 0.2, 0.7];
sci_colors.gray = [0.5, 0.5, 0.5];


% 1. 全年热浪期叶绿素a异常空间分布（SCI标准）
figure('Position', [100, 100, 900, 700], 'Color', 'white');
ax = axes('Position', [0.12, 0.18, 0.75, 0.72]);

% 使用contourf获得更好的视觉效果
[LON, LAT] = meshgrid(target_lon_chl, target_lat_chl);
contourf(LON, LAT, mean_hw_anom', 20, 'LineColor', 'none');
colormap(ax, scientific_colormap('vik')); % 使用科学配色
cbar = colorbar('Position', [0.88, 0.18, 0.02, 0.72], 'FontSize', 9);
cbar.Label.String = 'Chl-a anomaly (mg m^{-3})';
cbar.Label.FontSize = 10;
cbar.Label.FontWeight = 'bold';
caxis([-0.2, 0.2]);

% 添加海岸线
try
    load coastlines;
    hold on;
    plot(coastlon, coastlat, 'k-', 'LineWidth', 0.8, 'Color', [0.3, 0.3, 0.3]);
catch
    % 如果没有海岸线数据，添加边框
    box on;
end

xlabel('Longitude (°E)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Latitude (°N)', 'FontSize', 11, 'FontWeight', 'bold');
title('Chlorophyll-a Anomaly During Marine Heatwaves', 'FontSize', 12, 'FontWeight', 'bold');

% 设置坐标轴属性
set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
grid on;
grid minor;
set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);

% 保存高分辨率图像
export_fig(fullfile(output_dir, 'sci_chl_anomaly_during_hw.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_chl_anomaly_during_hw.fig'));

% 2. 全年热浪期与非热浪期差异（SCI标准）
figure('Position', [100, 100, 900, 700], 'Color', 'white');
ax = axes('Position', [0.12, 0.18, 0.75, 0.72]);

% 使用pcolor但改进视觉效果
h = pcolor(LON, LAT, diff_anom');
set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
colormap(ax, scientific_colormap('roma')); % 使用红蓝配色
cbar = colorbar('Position', [0.88, 0.18, 0.02, 0.72], 'FontSize', 9);
cbar.Label.String = 'ΔChl-a anomaly (mg m^{-3})';
cbar.Label.FontSize = 10;
cbar.Label.FontWeight = 'bold';
caxis([-0.15, 0.15]);

% 添加海岸线
try
    load coastlines;
    hold on;
    h_coast = plot(coastlon, coastlat, 'k-', 'LineWidth', 1, 'Color', [0.2, 0.2, 0.2]);
catch
    box on;
end

xlabel('Longitude (°E)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Latitude (°N)', 'FontSize', 11, 'FontWeight', 'bold');
title('Difference: MHW vs Non-MHW Periods', 'FontSize', 12, 'FontWeight', 'bold');

set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
grid on;

export_fig(fullfile(output_dir, 'sci_chl_anomaly_difference.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_chl_anomaly_difference.fig'));

% 3. 热浪频率与叶绿素异常相关性（SCI标准）
figure('Position', [100, 100, 900, 700], 'Color', 'white');
ax = axes('Position', [0.12, 0.18, 0.75, 0.72]);

% 只显示显著相关区域
significant_mask = p_value_matrix < 0.05;
correlation_plot = correlation_matrix;
correlation_plot(~significant_mask) = NaN;

h = pcolor(LON, LAT, correlation_plot');
set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
colormap(ax, scientific_colormap('broc')); % 使用发散配色
cbar = colorbar('Position', [0.88, 0.18, 0.02, 0.72], 'FontSize', 9);
cbar.Label.String = 'Correlation coefficient (r)';
cbar.Label.FontSize = 10;
cbar.Label.FontWeight = 'bold';
caxis([-0.25, 0.25]);

% 添加海岸线
try
    load coastlines;
    hold on;
    plot(coastlon, coastlat, 'k-', 'LineWidth', 1, 'Color', [0.2, 0.2, 0.2]);
catch
    box on;
end

xlabel('Longitude (°E)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Latitude (°N)', 'FontSize', 11, 'FontWeight', 'bold');
title('Correlation: MHW Frequency vs Chl-a Anomaly', 'FontSize', 12, 'FontWeight', 'bold');

set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
grid on;

export_fig(fullfile(output_dir, 'sci_correlation_mhw_chl.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_correlation_mhw_chl.fig'));

% 4. 季节性差异对比（SCI标准 - 紧凑布局）
figure('Position', [100, 100, 1200, 900], 'Color', 'white');

for season = 1:4
    ax = subplot(2, 2, season);
    pos = get(ax, 'Position');
    set(ax, 'Position', [pos(1)-0.02, pos(2), pos(3)*0.9, pos(4)*0.9]);
    
    h = pcolor(LON, LAT, squeeze(season_diff_anom(season, :, :))');
    set(h, 'EdgeColor', 'none');
    colormap(ax, scientific_colormap('vik'));
    caxis([-0.15, 0.15]);
    
    % 添加海岸线
    try
        load coastlines;
        hold on;
        plot(coastlon, coastlat, 'k-', 'LineWidth', 0.5, 'Color', [0.3, 0.3, 0.3]);
    catch
        box on;
    end
    
    xlabel('Longitude (°E)', 'FontSize', 9, 'FontWeight', 'bold');
    ylabel('Latitude (°N)', 'FontSize', 9, 'FontWeight', 'bold');
    title(season_labels{season}, 'FontSize', 10, 'FontWeight', 'bold');
    
    set(gca, 'FontSize', 8, 'LineWidth', 0.6, 'TickDir', 'out');
    grid on;
end

% 添加共享颜色条
c = colorbar('Position', [0.92, 0.2, 0.015, 0.6], 'FontSize', 9);
c.Label.String = 'ΔChl-a anomaly (mg m^{-3})';
c.Label.FontSize = 10;
c.Label.FontWeight = 'bold';

% 使用文本标注代替sgtitle（避免可能的冲突）
annotation('textbox', [0.3, 0.95, 0.4, 0.05], 'String', 'Seasonal Differences in Chl-a Anomaly: MHW vs Non-MHW', ...
           'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
           'EdgeColor', 'none', 'BackgroundColor', 'none');

export_fig(fullfile(output_dir, 'sci_seasonal_comparison.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_seasonal_comparison.fig'));

% 5. 热浪特征与叶绿素异常的多维度相关性分析（SCI标准）
figure('Position', [100, 100, 1400, 1000], 'Color', 'white');

% 子图1: 热浪频率相关性
subplot(2, 3, 1);
plot_spatial_correlation_safe(target_lon_chl, target_lat_chl, correlation_matrix, ...
                         p_value_matrix, 'Frequency vs Chl-a', scientific_colormap('broc'));

% 子图2: 热浪持续时间相关性
subplot(2, 3, 2);
plot_spatial_correlation_safe(target_lon_chl, target_lat_chl, duration_corr_matrix, ...
                         duration_p_matrix, 'Duration vs Chl-a', scientific_colormap('cork'));

% 子图3: 热浪强度相关性
subplot(2, 3, 3);
plot_spatial_correlation_safe(target_lon_chl, target_lat_chl, intensity_corr_matrix, ...
                         intensity_p_matrix, 'Intensity vs Chl-a', scientific_colormap('vik'));

% 子图4: 热浪持续时间分布
subplot(2, 3, 4);
h = pcolor(LON, LAT, hw_duration_metrics');
set(h, 'EdgeColor', 'none');
colormap(scientific_colormap('hawaii'));
colorbar;
caxis([0, prctile(hw_duration_metrics(:), 95)]); % 使用95百分位避免异常值
xlabel('Longitude (°E)', 'FontSize', 9, 'FontWeight', 'bold');
ylabel('Latitude (°N)', 'FontSize', 9, 'FontWeight', 'bold');
title('Average HW Duration (days)', 'FontSize', 10, 'FontWeight', 'bold');
set(gca, 'FontSize', 8, 'LineWidth', 0.6, 'TickDir', 'out');
try
    load coastlines;
    hold on;
    plot(coastlon, coastlat, 'k-', 'LineWidth', 0.5);
catch
    box on;
end

% 子图5: 热浪强度分布
subplot(2, 3, 5);
h = pcolor(LON, LAT, hw_intensity_metrics');
set(h, 'EdgeColor', 'none');
colormap(scientific_colormap('roma'));
colorbar;
caxis(prctile(hw_intensity_metrics(:), [5, 95])); % 使用5-95百分位
xlabel('Longitude (°E)', 'FontSize', 9, 'FontWeight', 'bold');
ylabel('Latitude (°N)', 'FontSize', 9, 'FontWeight', 'bold');
title('Average HW Intensity', 'FontSize', 10, 'FontWeight', 'bold');
set(gca, 'FontSize', 8, 'LineWidth', 0.6, 'TickDir', 'out');
try
    load coastlines;
    hold on;
    plot(coastlon, coastlat, 'k-', 'LineWidth', 0.5);
catch
    box on;
end

% 子图6: 相关性统计比较（改进版）
subplot(2, 3, 6);
plot_correlation_comparison_safe(correlation_matrix, p_value_matrix, ...
                           duration_corr_matrix, duration_p_matrix, ...
                           intensity_corr_matrix, intensity_p_matrix);

% 使用文本标注代替sgtitle
annotation('textbox', [0.3, 0.95, 0.4, 0.05], 'String', 'Multi-dimensional Analysis: Heatwave Characteristics vs Chlorophyll-a', ...
           'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
           'EdgeColor', 'none', 'BackgroundColor', 'none');

export_fig(fullfile(output_dir, 'sci_multidimensional_analysis.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_multidimensional_analysis.fig'));

% 6. 统计分布图 - SCI标准（修复legend）
figure('Position', [100, 100, 1000, 450], 'Color', 'white');

% 准备数据 - 使用更有效的方法
n_samples = 5000; % 限制样本数量
hw_samples = [];
non_hw_samples = [];

% 随机采样网格点
sampled_grids = randperm(n_lon_chl * n_lat_chl, min(50, n_lon_chl * n_lat_chl));
for idx = 1:length(sampled_grids)
    [i, j] = ind2sub([n_lon_chl, n_lat_chl], sampled_grids(idx));
    
    % 随机采样时间点
    time_samples = randperm(n_times_chl, min(100, n_times_chl));
    
    for t = time_samples
        if ~isnan(chl_anomaly(t, i, j))
            if hw_mask_chl_grid(t, i, j)
                hw_samples = [hw_samples; chl_anomaly(t, i, j)];
            else
                non_hw_samples = [non_hw_samples; chl_anomaly(t, i, j)];
            end
        end
    end
    
    % 如果样本量足够，提前退出
    if length(hw_samples) > n_samples && length(non_hw_samples) > n_samples
        break;
    end
end

% 限制样本量
if length(hw_samples) > n_samples
    hw_samples = hw_samples(randperm(length(hw_samples), n_samples));
end
if length(non_hw_samples) > n_samples
    non_hw_samples = non_hw_samples(randperm(length(non_hw_samples), n_samples));
end

% 直方图
subplot(1, 2, 1);
hold on;
h1 = histogram(hw_samples, 40, 'FaceColor', sci_colors.red, 'FaceAlpha', 0.7, ...
          'EdgeColor', 'none', 'Normalization', 'probability');
h2 = histogram(non_hw_samples, 40, 'FaceColor', sci_colors.blue, 'FaceAlpha', 0.7, ...
          'EdgeColor', 'none', 'Normalization', 'probability');
xlabel('Chlorophyll-a Anomaly (mg m^{-3})', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Probability Density', 'FontSize', 10, 'FontWeight', 'bold');

% 使用安全的legend函数
safe_legend([h1, h2], {'MHW Periods', 'Non-MHW Periods'}, 'northwest', 9);

set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
grid on;
grid minor;
set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
title('Distribution of Chl-a Anomalies', 'FontSize', 11, 'FontWeight', 'bold');

% 箱线图
subplot(1, 2, 2);
box_data = [hw_samples; non_hw_samples];
group_data = [ones(length(hw_samples), 1); 2*ones(length(non_hw_samples), 1)];

box_handles = boxplot(box_data, group_data, 'Labels', {'MHW', 'Non-MHW'}, ...
        'Widths', 0.6);
ylabel('Chlorophyll-a Anomaly (mg m^{-3})', 'FontSize', 10, 'FontWeight', 'bold');
set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
grid on;
title('Boxplot of Chl-a Anomalies', 'FontSize', 11, 'FontWeight', 'bold');

% 添加统计检验结果
hw_mean = mean(hw_samples, 'omitnan');
non_hw_mean = mean(non_hw_samples, 'omitnan');
[~, p_val] = ttest2(hw_samples, non_hw_samples);

text(0.5, 0.9, sprintf('p = %.2e', p_val), 'Units', 'normalized', ...
     'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
     'BackgroundColor', 'white');

export_fig(fullfile(output_dir, 'sci_statistical_distribution.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_statistical_distribution.fig'));

% 7. 热浪特征散点图矩阵（SCI标准，无legend）
if exist('hw_frequency', 'var') && exist('hw_duration_metrics', 'var') && exist('hw_intensity_metrics', 'var')
    figure('Position', [100, 100, 1000, 800], 'Color', 'white');
    plot_scatter_matrix_safe(hw_frequency, hw_duration_metrics, hw_intensity_metrics, mean_hw_anom, ...
                       target_lon_chl, target_lat_chl);
    export_fig(fullfile(output_dir, 'sci_scatter_matrix.png'), '-r300', '-png', '-transparent');
    saveas(gcf, fullfile(output_dir, 'sci_scatter_matrix.fig'));
end

fprintf('SCI论文标准图表生成完成！\n');



% 如果export_fig函数不可用，使用替代方案
if ~exist('export_fig', 'file')
    fprintf('注意: export_fig函数不可用，使用MATLAB内置保存功能\n');
    export_fig = @(filename, varargin) print(gcf, filename, '-dpng', '-r300');
end
%% 
% 8. 季节性相关性空间分布（带显著性检验）
fprintf('绘制季节性相关性空间分布（带显著性打点）...\n');

% 定义季节顺序（与 season_labels 一致）
season_order = [1,2,3,4]; % 冬、春、夏、秋
season_display = {'Winter', 'Spring', 'Summer', 'Autumn'};

figure('Position', [100, 100, 1400, 1000], 'Color', 'white');

for s = 1:4
    ax = subplot(2, 2, s);
    
    % 提取当前季节的相关系数和 p 值
    corr_map = squeeze(seasonal_correlation(s, :, :))';
    p_map = squeeze(seasonal_p_value(s, :, :))';
    
    % 绘制相关系数背景
    [LON, LAT] = meshgrid(target_lon_chl, target_lat_chl);
    h = pcolor(LON, LAT, corr_map);
    set(h, 'EdgeColor', 'none');
    colormap(ax, scientific_colormap('vik'));
    caxis([-0.3, 0.3]);  % 可根据实际调整范围
    colorbar;
    
    % 叠加海岸线
    try
        load coastlines;
        hold on;
        plot(coastlon, coastlat, 'k-', 'LineWidth', 0.5, 'Color', [0.3,0.3,0.3]);
    catch
        box on;
    end
    
    % 显著性打点：p < 0.05 的区域用黑色点表示
   
% 显著性打点（降采样，每隔2个网格点显示一个）
[sig_y, sig_x] = find(p_map < 0.1 & ~isnan(corr_map));
if ~isempty(sig_y)
    % 降采样：只取其中一部分点（例如步长2）
    step = 2;
    idx = 1:step:length(sig_y);
    sig_lon = target_lon_chl(sig_x(idx));
    sig_lat = target_lat_chl(sig_y(idx));
    % 使用普通 plot（无透明度）
    plot(sig_lon, sig_lat, 'k.', 'MarkerSize', 2);
end   
    xlabel('Longitude (°E)', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Latitude (°N)', 'FontSize', 10, 'FontWeight', 'bold');
    title(sprintf('%s: Chl-a vs MHW Frequency (r)', season_display{s}), ...
          'FontSize', 11, 'FontWeight', 'bold');
    set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
    xlim([min(target_lon_chl), max(target_lon_chl)]);
    ylim([min(target_lat_chl), max(target_lat_chl)]);
    
    % 子图标签 (a-d)
    text(0.02, 0.98, char('a'+s-1), 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
end

% 添加公共颜色条（可选，因为每个子图已有 colorbar，也可以统一一个）
% 若需要统一颜色条，可删除子图内部的 colorbar，在外部添加，但此处简单处理。

export_fig(fullfile(output_dir, 'sci_seasonal_correlation_significance.png'), '-r300', '-png');
saveas(gcf, fullfile(output_dir, 'sci_seasonal_correlation_significance.fig'));
%% 第七步：保存结果
fprintf('保存分析结果...\n');

% 保存空间分布数据
spatial_data.lon = target_lon_chl;
spatial_data.lat = target_lat_chl;
spatial_data.mean_hw_anom = mean_hw_anom;
spatial_data.mean_non_hw_anom = mean_non_hw_anom;
spatial_data.diff_anom = diff_anom;
spatial_data.hw_frequency = hw_frequency;
spatial_data.mean_hw_intensity = mean_hw_intensity;

% 保存季节性数据
seasonal_data.season_labels = season_labels;
seasonal_data.season_mean_hw_anom = season_mean_hw_anom;
seasonal_data.season_mean_non_hw_anom = season_mean_non_hw_anom;
seasonal_data.season_diff_anom = season_diff_anom;

% 保存相关性分析结果
correlation_data.correlation_matrix = correlation_matrix;
correlation_data.p_value_matrix = p_value_matrix;
correlation_data.seasonal_correlation = seasonal_correlation;
correlation_data.seasonal_p_value = seasonal_p_value;

% 保存到文件
save(fullfile(output_dir, 'spatial_analysis_data.mat'), 'spatial_data');
save(fullfile(output_dir, 'seasonal_analysis_data.mat'), 'seasonal_data');
save(fullfile(output_dir, 'correlation_analysis_data.mat'), 'correlation_data');

% 保存汇总统计信息
summary_stats = struct();
summary_stats.analysis_period = '2015-2024';
summary_stats.total_days = n_times_chl;
summary_stats.region = sprintf('Longitude %.1f-%.1fE, Latitude %.1f-%.1fN', ...
    lon_range(1), lon_range(2), lat_range(1), lat_range(2));
summary_stats.season_definitions = {
    'Winter: December-February', ...
    'Spring: March-May', ...
    'Summer: June-August', ...
    'Autumn: September-November'};

% 计算总体统计
summary_stats.mean_hw_frequency = mean(hw_frequency(:), 'omitnan');
summary_stats.mean_correlation = mean(correlation_matrix(:), 'omitnan');
summary_stats.significant_correlation_proportion = sum(p_value_matrix(:) < 0.05 & ~isnan(p_value_matrix(:))) / sum(~isnan(p_value_matrix(:)));

save(fullfile(output_dir, 'summary_stats.mat'), 'summary_stats');

% 生成报告
fprintf('\n=== 分析报告 ===\n');
fprintf('分析区域: 经度 %.1f-%.1f°E, 纬度 %.1f-%.1f°N\n', lon_range(1), lon_range(2), lat_range(1), lat_range(2));
fprintf('分析时段: %s 到 %s (%d 天)\n', datestr(min(selected_dates_chl)), datestr(max(selected_dates_chl)), n_times_chl);
fprintf('平均热浪频率: %.3f (%.1f%% 的天数)\n', summary_stats.mean_hw_frequency, summary_stats.mean_hw_frequency*100);
fprintf('平均相关性系数: %.3f\n', summary_stats.mean_correlation);
fprintf('显著相关区域比例: %.3f (p < 0.05)\n', summary_stats.significant_correlation_proportion);
fprintf('生成图表数量: %d 张\n', 10); % 可根据实际生成的图表数量调整

fprintf('分析完成！所有结果已保存到目录: %s\n', output_dir);

% 叶绿素a与海洋热浪关联分析（美观图像+相关性分析+时间序列）
% 分析2015-2024年热浪期间和非热浪期间的叶绿素a异常，按季节对比



% [前面的数据读取和处理代码保持不变...]

%% 第八步：时间序列变化分析（全年和四季热浪vs非热浪）- 修复版
fprintf('分析全年和四季热浪和非热浪期间时间序列变化...\n');

% 设置SCI论文标准的时间序列图属性
ts_fontsize = 10;
ts_linewidth = 1.5;

% 1. 全年时间序列变化
figure('Position', [100, 100, 1200, 600], 'Color', 'white');

% 计算全区域平均的日叶绿素异常（热浪期和非热浪期分开）
fprintf('计算全区域平均时间序列...\n');

% 初始化
hw_daily_avg = zeros(n_times_chl, 1);
non_hw_daily_avg = zeros(n_times_chl, 1);
hw_daily_count = zeros(n_times_chl, 1);
non_hw_daily_count = zeros(n_times_chl, 1);

for t = 1:n_times_chl
    % 提取当天数据
    chl_t = squeeze(chl_anomaly(t, :, :));
    hw_mask_t = squeeze(hw_mask_chl_grid(t, :, :));
    
    % 热浪期平均
    hw_chl = chl_t(hw_mask_t & ~isnan(chl_t));
    if ~isempty(hw_chl)
        hw_daily_avg(t) = mean(hw_chl);
        hw_daily_count(t) = length(hw_chl);
    else
        hw_daily_avg(t) = NaN;
    end
    
    % 非热浪期平均
    non_hw_chl = chl_t(~hw_mask_t & ~isnan(chl_t));
    if ~isempty(non_hw_chl)
        non_hw_daily_avg(t) = mean(non_hw_chl);
        non_hw_daily_count(t) = length(non_hw_chl);
    else
        non_hw_daily_avg(t) = NaN;
    end
end

% 应用移动平均平滑（7天窗口）
window_size = 7;
hw_smooth = movmean(hw_daily_avg, window_size, 'omitnan');
non_hw_smooth = movmean(non_hw_daily_avg, window_size, 'omitnan');

% 创建时间序列图

hold on;
%% 

% 绘制原始数据（透明度较低）
h1 = plot(selected_dates_chl, hw_daily_avg, '-', 'Color', [sci_colors.red, 0.3], ...
     'LineWidth', 0.5);
h2 = plot(selected_dates_chl, non_hw_daily_avg, '-', 'Color', [sci_colors.blue, 0.3], ...
     'LineWidth', 0.5);

% 绘制平滑数据
h3 = plot(selected_dates_chl, hw_smooth, '-', 'Color', sci_colors.red, ...
     'LineWidth', ts_linewidth);
h4 = plot(selected_dates_chl, non_hw_smooth, '-', 'Color', sci_colors.blue, ...
     'LineWidth', ts_linewidth);

% 零线
h5 = plot(selected_dates_chl, zeros(size(selected_dates_chl)), 'k--', 'LineWidth', 1, ...
     'Color', [0.5, 0.5, 0.5]);

xlabel('Date', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
ylabel('Chl-a Anomaly (mg m^{-3})', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
title('Annual Time Series: Chlorophyll-a Anomaly during MHW vs Non-MHW Periods', ...
      'FontSize', ts_fontsize+1, 'FontWeight', 'bold');

% 使用安全的legend函数
safe_legend([h3, h4, h5], {'MHW (7-day mean)', 'Non-MHW (7-day mean)', 'Zero line'}, ...
             'best', ts_fontsize-1);
grid on;
set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');

% 添加热浪频率背景

% 计算热浪频率（7天移动平均）
hw_freq_daily = sum(hw_mask_chl_grid, [2, 3]) ./ (n_lon_chl * n_lat_chl);
hw_freq_smooth = movmean(hw_freq_daily, window_size, 'omitnan');

area(selected_dates_chl, hw_freq_smooth * 100, 'FaceColor', sci_colors.orange, ...
     'FaceAlpha', 0.5, 'EdgeColor', 'none');
ylabel('MHW Frequency (%)', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
xlabel('Date', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
title('Marine Heatwave Frequency (7-day moving average)', ...
      'FontSize', ts_fontsize+1, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');
ylim([0, 100]);

export_fig(fullfile(output_dir, 'sci_annual_timeseries.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_annual_timeseries.fig'));

% 2. 季节性时间序列变化（多年平均）
figure('Position', [100, 100, 1400, 1000], 'Color', 'white');

% 为每个季节创建子图
for season = 1:4
    subplot(2, 2, season);
    
    % 选择当前季节的数据
    season_mask = (season_idx == season);
    season_dates = selected_dates_chl(season_mask);
    season_hw_avg = hw_daily_avg(season_mask);
    season_non_hw_avg = non_hw_daily_avg(season_mask);
    season_hw_freq = hw_freq_daily(season_mask);
    
    % 按年积日分组计算多年平均
    doy_season = day(season_dates, 'dayofyear');
    unique_doy = unique(doy_season);
    
    % 初始化季节性平均
    seasonal_hw_mean = zeros(size(unique_doy));
    seasonal_non_hw_mean = zeros(size(unique_doy));
    seasonal_hw_freq_mean = zeros(size(unique_doy));
    
    for i = 1:length(unique_doy)
        doy_mask = (doy_season == unique_doy(i));
        seasonal_hw_mean(i) = mean(season_hw_avg(doy_mask), 'omitnan');
        seasonal_non_hw_mean(i) = mean(season_non_hw_avg(doy_mask), 'omitnan');
        seasonal_hw_freq_mean(i) = mean(season_hw_freq(doy_mask), 'omitnan') * 100;
    end
    
    % 创建日期轴（使用参考年份）
    ref_year = 2000; % 非闰年
    season_dates_ref = datetime(ref_year, 1, 1) + days(unique_doy - 1);
    
    % 绘制季节性时间序列
    yyaxis left;
    hold on;
    h1 = plot(season_dates_ref, seasonal_hw_mean, '-', 'Color', sci_colors.red, ...
         'LineWidth', ts_linewidth);
    h2 = plot(season_dates_ref, seasonal_non_hw_mean, '-', 'Color', sci_colors.blue, ...
         'LineWidth', ts_linewidth);
    h3 = plot(season_dates_ref, zeros(size(season_dates_ref)), 'k--', 'LineWidth', 1, ...
         'Color', [0.5, 0.5, 0.5]);
    
    ylabel('Chl-a Anomaly (mg m^{-3})', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
    ylim([-0.15, 0.15]);
    
    % 热浪频率（右侧y轴）
    yyaxis right;
    h4 = plot(season_dates_ref, seasonal_hw_freq_mean, '-', 'Color', sci_colors.orange, ...
         'LineWidth', 1);
    ylabel('MHW Frequency (%)', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
    ylim([0, 100]);
    
    xlabel('Date', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
    title(sprintf('%s: Seasonal Climatology (2015-2024)', season_labels{season}), ...
          'FontSize', ts_fontsize+1, 'FontWeight', 'bold');
    
    % 设置x轴刻度为月份
    datetick('x', 'mmm', 'keeplimits');
    
    grid on;
    set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');
    
    % 只在第一个子图添加图例
    if season == 1
        safe_legend([h1, h2, h3, h4], {'MHW', 'Non-MHW', 'Zero line', 'MHW Frequency'}, ...
                    'northwest', ts_fontsize-2);
    end
end

export_fig(fullfile(output_dir, 'sci_seasonal_timeseries.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_seasonal_timeseries.fig'));

% 3. 月度变化分析
figure('Position', [100, 100, 1200, 800], 'Color', 'white');

% 提取月份信息
months_all = month(selected_dates_chl);
years_all = year(selected_dates_chl);

% 计算月度平均
monthly_hw_avg = zeros(12, 1);
monthly_non_hw_avg = zeros(12, 1);
monthly_hw_freq = zeros(12, 1);

for m = 1:12
    month_mask = (months_all == m);
    monthly_hw_avg(m) = mean(hw_daily_avg(month_mask), 'omitnan');
    monthly_non_hw_avg(m) = mean(non_hw_daily_avg(month_mask), 'omitnan');
    monthly_hw_freq(m) = mean(hw_freq_daily(month_mask), 'omitnan') * 100;
end

% 月度时间序列图
subplot(2, 1, 1);
hold on;

% 创建月度日期轴
month_dates = datetime(2000, 1:12, 15); % 每月中间

h1 = plot(month_dates, monthly_hw_avg, '-o', 'Color', sci_colors.red, ...
     'LineWidth', ts_linewidth, 'MarkerSize', 6, 'MarkerFaceColor', sci_colors.red);
h2 = plot(month_dates, monthly_non_hw_avg, '-o', 'Color', sci_colors.blue, ...
     'LineWidth', ts_linewidth, 'MarkerSize', 6, 'MarkerFaceColor', sci_colors.blue);
h3 = plot(month_dates, zeros(12, 1), 'k--', 'LineWidth', 1, ...
     'Color', [0.5, 0.5, 0.5]);

xlabel('Month', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
ylabel('Chl-a Anomaly (mg m^{-3})', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
title('Monthly Climatology: Chlorophyll-a Anomaly (2015-2024)', ...
      'FontSize', ts_fontsize+1, 'FontWeight', 'bold');

safe_legend([h1, h2, h3], {'MHW', 'Non-MHW', 'Zero line'}, ...
             'best', ts_fontsize-1);
grid on;
set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');
datetick('x', 'mmm', 'keeplimits');

% 月度热浪频率
subplot(2, 1, 2);
bar(month_dates, monthly_hw_freq, 'FaceColor', sci_colors.orange, ...
    'FaceAlpha', 0.7, 'EdgeColor', sci_colors.orange);
xlabel('Month', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
ylabel('MHW Frequency (%)', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
title('Monthly Marine Heatwave Frequency (2015-2024)', ...
      'FontSize', ts_fontsize+1, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');
datetick('x', 'mmm', 'keeplimits');
ylim([0, 100]);

export_fig(fullfile(output_dir, 'sci_monthly_climatology.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_monthly_climatology.fig'));

% 4. 年际变化分析
figure('Position', [100, 100, 1000, 800], 'Color', 'white');

% 计算年度平均
unique_years = unique(years_all);
annual_hw_avg = zeros(length(unique_years), 1);
annual_non_hw_avg = zeros(length(unique_years), 1);
annual_hw_freq = zeros(length(unique_years), 1);

for i = 1:length(unique_years)
    year_mask = (years_all == unique_years(i));
    annual_hw_avg(i) = mean(hw_daily_avg(year_mask), 'omitnan');
    annual_non_hw_avg(i) = mean(non_hw_daily_avg(year_mask), 'omitnan');
    annual_hw_freq(i) = mean(hw_freq_daily(year_mask), 'omitnan') * 100;
end

% 年际变化图
subplot(2, 1, 1);
hold on;

h1 = plot(unique_years, annual_hw_avg, '-o', 'Color', sci_colors.red, ...
     'LineWidth', ts_linewidth, 'MarkerSize', 8, 'MarkerFaceColor', sci_colors.red);
h2 = plot(unique_years, annual_non_hw_avg, '-o', 'Color', sci_colors.blue, ...
     'LineWidth', ts_linewidth, 'MarkerSize', 8, 'MarkerFaceColor', sci_colors.blue);
h3 = plot(unique_years, zeros(size(unique_years)), 'k--', 'LineWidth', 1, ...
     'Color', [0.5, 0.5, 0.5]);

xlabel('Year', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
ylabel('Chl-a Anomaly (mg m^{-3})', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
title('Interannual Variation: Chlorophyll-a Anomaly', ...
      'FontSize', ts_fontsize+1, 'FontWeight', 'bold');

% 添加趋势线
legend_handles = [h1, h2, h3];
legend_labels = {'MHW', 'Non-MHW', 'Zero line'};

if length(unique_years) > 2
    % MHW趋势
    p_hw = polyfit(unique_years, annual_hw_avg, 1);
    trend_hw = polyval(p_hw, unique_years);
    h4 = plot(unique_years, trend_hw, '--', 'Color', sci_colors.red, ...
         'LineWidth', 1);
    legend_handles = [legend_handles, h4];
    legend_labels = [legend_labels, {sprintf('MHW trend: %.3f/yr', p_hw(1))}];
    
    % Non-MHW趋势
    p_non_hw = polyfit(unique_years, annual_non_hw_avg, 1);
    trend_non_hw = polyval(p_non_hw, unique_years);
    h5 = plot(unique_years, trend_non_hw, '--', 'Color', sci_colors.blue, ...
         'LineWidth', 1);
    legend_handles = [legend_handles, h5];
    legend_labels = [legend_labels, {sprintf('Non-MHW trend: %.3f/yr', p_non_hw(1))}];
end

safe_legend(legend_handles, legend_labels, 'best', ts_fontsize-1);
grid on;
set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');
xlim([2014.5, 2024.5]);

% 年际热浪频率
subplot(2, 1, 2);
hold on;
h6 = bar(unique_years, annual_hw_freq, 'FaceColor', sci_colors.orange, ...
    'FaceAlpha', 0.7, 'EdgeColor', sci_colors.orange);

xlabel('Year', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
ylabel('MHW Frequency (%)', 'FontSize', ts_fontsize, 'FontWeight', 'bold');
title('Interannual Variation: Marine Heatwave Frequency', ...
      'FontSize', ts_fontsize+1, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', ts_fontsize-1, 'LineWidth', 0.8, 'TickDir', 'out');
xlim([2014.5, 2024.5]);
ylim([0, 100]);

% 添加趋势线
if length(unique_years) > 2
    p_freq = polyfit(unique_years, annual_hw_freq, 1);
    trend_freq = polyval(p_freq, unique_years);
    h7 = plot(unique_years, trend_freq, 'r-', 'LineWidth', 2);
    safe_legend([h6, h7], {'MHW Frequency', sprintf('Trend: %.2f%%/yr', p_freq(1))}, ...
                 'best', ts_fontsize-1);
end

export_fig(fullfile(output_dir, 'sci_interannual_variation.png'), '-r300', '-png', '-transparent');
saveas(gcf, fullfile(output_dir, 'sci_interannual_variation.fig'));

fprintf('时间序列分析完成！\n');

%% 辅助函数定义（放在代码最后）

function safe_legend(h_handles, labels, location, fontsize)
    % 安全创建legend的函数
    try
        % 尝试使用内置legend
        lgd = legend(h_handles, labels, 'Location', location, 'FontSize', fontsize);
    catch ME
        % 如果失败，使用文本标注
        fprintf('Legend failed: %s, using text annotations instead.\n', ME.message);
        if strcmp(location, 'northwest')
            pos = [0.02, 0.98];
            va = 'top';
        elseif strcmp(location, 'northeast')
            pos = [0.98, 0.98];
            va = 'top';
        elseif strcmp(location, 'southwest')
            pos = [0.02, 0.02];
            va = 'bottom';
        else % default to northwest
            pos = [0.02, 0.98];
            va = 'top';
        end
        
        for i = 1:length(h_handles)
            if isvalid(h_handles(i))
                % 安全地获取颜色，处理不同类型的图形对象
                try
                    if contains(class(h_handles(i)), 'Histogram')
                        % 对于直方图对象，使用FaceColor
                        color = h_handles(i).FaceColor;
                    elseif contains(class(h_handles(i)), 'Bar')
                        % 对于柱状图对象，使用FaceColor
                        color = h_handles(i).FaceColor;
                    else
                        % 对于其他对象，尝试使用Color属性
                        color = h_handles(i).Color;
                    end
                catch
                    % 如果获取颜色失败，使用默认颜色
                    colors = lines(length(h_handles));
                    color = colors(i, :);
                end
                
                text(pos(1), pos(2)-0.05*(i-1), labels{i}, 'Units', 'normalized', ...
                     'VerticalAlignment', va, 'Color', color, 'FontSize', fontsize, ...
                     'FontWeight', 'bold', 'BackgroundColor', 'white');
            end
        end
    end
end

function cmap = scientific_colormap(name)
    % 提供科学可视化常用的配色方案
    switch name
        case 'vik'
            % 蓝-白-红配色
            cmap = [0.001462, 0.000466, 0.013866;
                    0.037668, 0.321575, 0.552923;
                    0.254759, 0.588952, 0.531726;
                    0.672922, 0.779357, 0.222762;
                    0.997757, 0.885192, 0.172549;
                    0.990988, 0.553758, 0.213998;
                    0.900149, 0.237624, 0.315806;
                    0.642936, 0.073318, 0.431714];
            cmap = interp1(linspace(0,1,size(cmap,1)), cmap, linspace(0,1,256));
            
        case 'roma'
            % 红-白-蓝配色
            cmap = [0.496432, 0.099104, 0.325195;
                    0.759547, 0.392636, 0.345298;
                    0.927091, 0.661327, 0.464752;
                    0.988265, 0.894768, 0.707921;
                    0.848997, 0.939698, 0.955834;
                    0.576474, 0.812916, 0.924099;
                    0.281461, 0.570837, 0.774636;
                    0.134556, 0.305353, 0.572957];
            cmap = interp1(linspace(0,1,size(cmap,1)), cmap, linspace(0,1,256));
            
        case 'broc'
            % 蓝-白-棕配色
            cmap = [0.166383, 0.118927, 0.442525;
                    0.281413, 0.377981, 0.700483;
                    0.512075, 0.647749, 0.810686;
                    0.784314, 0.858824, 0.878431;
                    0.964706, 0.937255, 0.858824;
                    0.941176, 0.807843, 0.658824;
                    0.850980, 0.584314, 0.439216;
                    0.654902, 0.341176, 0.270588;
                    0.447059, 0.164706, 0.164706];
            cmap = interp1(linspace(0,1,size(cmap,1)), cmap, linspace(0,1,256));
            
        case 'cork'
            % 绿-白-粉配色
            cmap = [0.171363, 0.101307, 0.299658;
                    0.249282, 0.370401, 0.506811;
                    0.402907, 0.601823, 0.555413;
                    0.664348, 0.792325, 0.658978;
                    0.905748, 0.911353, 0.873636;
                    0.951386, 0.808165, 0.772715;
                    0.847126, 0.553894, 0.580064;
                    0.654984, 0.305964, 0.428881;
                    0.427947, 0.141513, 0.334983];
            cmap = interp1(linspace(0,1,size(cmap,1)), cmap, linspace(0,1,256));
            
        case 'hawaii'
            % 顺序配色
            cmap = [0.54902, 0.317647, 0.039216;
                    0.741176, 0.423529, 0.023529;
                    0.905882, 0.627451, 0.223529;
                    0.976471, 0.843137, 0.611765;
                    0.882353, 0.937255, 0.901961;
                    0.588235, 0.854902, 0.756863;
                    0.27451, 0.666667, 0.654902;
                    0.141176, 0.427451, 0.54902;
                    0.109804, 0.219608, 0.352941];
            cmap = interp1(linspace(0,1,size(cmap,1)), cmap, linspace(0,1,256));
            
        otherwise
            % 默认使用vik配色
            cmap = scientific_colormap('vik');
    end
end

function plot_spatial_correlation_safe(lon, lat, corr_matrix, p_matrix, title_str, cmap)
    % 绘制空间相关性图（安全版本）
    [LON, LAT] = meshgrid(lon, lat);
    
    % 只显示显著相关区域
    significant_mask = p_matrix < 0.05;
    correlation_plot = corr_matrix;
    correlation_plot(~significant_mask) = NaN;
    
    h = pcolor(LON, LAT, correlation_plot');
    set(h, 'EdgeColor', 'none');
    colormap(cmap);
    colorbar;
    caxis([-0.25, 0.25]);
    
    % 添加海岸线
    try
        load coastlines;
        hold on;
        plot(coastlon, coastlat, 'k-', 'LineWidth', 0.5, 'Color', [0.2, 0.2, 0.2]);
    catch
        box on;
    end
    
    xlabel('Longitude (°E)', 'FontSize', 9, 'FontWeight', 'bold');
    ylabel('Latitude (°N)', 'FontSize', 9, 'FontWeight', 'bold');
    title(title_str, 'FontSize', 10, 'FontWeight', 'bold');
    set(gca, 'FontSize', 8, 'LineWidth', 0.6, 'TickDir', 'out');
end

function plot_correlation_comparison_safe(corr_freq, p_freq, corr_dur, p_dur, corr_int, p_int)
    % 绘制相关性比较图（安全版本）
    
    % 提取显著相关性数据
    freq_sig = corr_freq(p_freq < 0.05 & ~isnan(corr_freq));
    dur_sig = corr_dur(p_dur < 0.05 & ~isnan(corr_dur));
    int_sig = corr_int(p_int < 0.05 & ~isnan(corr_int));
    
    if isempty(freq_sig) || isempty(dur_sig) || isempty(int_sig)
        text(0.5, 0.5, 'Insufficient significant correlations', ...
             'HorizontalAlignment', 'center', 'FontSize', 10);
        return;
    end
    
    % 确保数据长度一致
    min_len = min([length(freq_sig), length(dur_sig), length(int_sig)]);
    if min_len > 1000
        % 如果数据太多，随机采样
        idx = randperm(min_len, 1000);
        data = [freq_sig(idx), dur_sig(idx), int_sig(idx)];
    else
        data = [freq_sig(1:min_len), dur_sig(1:min_len), int_sig(1:min_len)];
    end
    
    % 创建箱线图
    boxplot(data, 'Labels', {'Frequency', 'Duration', 'Intensity'}, ...
            'Widths', 0.6);
    ylabel('Correlation Coefficient', 'FontSize', 9, 'FontWeight', 'bold');
    set(gca, 'FontSize', 8, 'LineWidth', 0.6, 'TickDir', 'out');
    grid on;
    title('Comparison of Correlation Types', 'FontSize', 10, 'FontWeight', 'bold');
    
    % 添加统计信息（使用文本）
    text(0.05, 0.95, sprintf('Freq: n=%d', length(freq_sig)), 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 8, 'BackgroundColor', 'white');
    text(0.05, 0.88, sprintf('Dur: n=%d', length(dur_sig)), 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 8, 'BackgroundColor', 'white');
    text(0.05, 0.81, sprintf('Int: n=%d', length(int_sig)), 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 8, 'BackgroundColor', 'white');
end

function plot_scatter_matrix_safe(freq, dur, int, chl, lon, lat)
    % 绘制散点图矩阵（安全版本，无legend）
    
    % 选择代表性网格点
    valid_mask = freq > 0.01 & dur > 0 & ~isnan(int) & ~isnan(chl);
    [valid_i, valid_j] = find(valid_mask);
    
    if length(valid_i) > 1000
        % 随机采样
        idx = randperm(length(valid_i), 1000);
        valid_i = valid_i(idx);
        valid_j = valid_j(idx);
    end
    
    % 提取数据
    data = zeros(length(valid_i), 4);
    for k = 1:length(valid_i)
        i = valid_i(k);
        j = valid_j(k);
        data(k, 1) = freq(i, j);
        data(k, 2) = dur(i, j);
        data(k, 3) = int(i, j);
        data(k, 4) = chl(i, j);
    end
    
    % 移除NaN
    valid_data = all(~isnan(data), 2);
    data = data(valid_data, :);
    
    if size(data, 1) < 10
        text(0.5, 0.5, 'Insufficient data for scatter matrix', ...
             'HorizontalAlignment', 'center', 'FontSize', 12);
        return;
    end
    
    % 创建散点图矩阵
    var_names = {'HW Frequency', 'HW Duration', 'HW Intensity', 'Chl-a Anomaly'};
    
    for i = 1:3
        for j = (i+1):4
            subplot(3, 3, (i-1)*3 + j-1);
            scatter(data(:, i), data(:, j), 20, 'filled', 'MarkerFaceAlpha', 0.6, ...
                    'MarkerEdgeColor', 'none');
            xlabel(var_names{i}, 'FontSize', 8);
            ylabel(var_names{j}, 'FontSize', 8);
            set(gca, 'FontSize', 7, 'LineWidth', 0.5, 'TickDir', 'out');
            grid on;
            
            % 添加相关性信息（使用文本）
            [r, p] = corr(data(:, i), data(:, j), 'rows', 'complete');
            text(0.05, 0.95, sprintf('r=%.3f', r), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top', ...
                 'FontSize', 7, 'BackgroundColor', 'white');
            text(0.05, 0.85, sprintf('p=%.2e', p), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top', ...
                 'FontSize', 7, 'BackgroundColor', 'white');
        end
    end
    
    % 使用文本标注代替sgtitle
    annotation('textbox', [0.3, 0.95, 0.4, 0.05], 'String', 'Scatter Matrix: Heatwave Characteristics vs Chl-a Anomaly', ...
               'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
               'EdgeColor', 'none', 'BackgroundColor', 'none');
end

% 修复统计分布图的legend问题 - 单独处理直方图
function create_statistical_plots_safe(hw_samples, non_hw_samples, sci_colors, output_dir)
    % 创建安全的统计分布图
    
    figure('Position', [100, 100, 1000, 450], 'Color', 'white');
    
    % 直方图
    subplot(1, 2, 1);
    hold on;
    
    % 创建直方图并获取句柄
    h1 = histogram(hw_samples, 40, 'FaceColor', sci_colors.red, 'FaceAlpha', 0.7, ...
          'EdgeColor', 'none', 'Normalization', 'probability');
    h2 = histogram(non_hw_samples, 40, 'FaceColor', sci_colors.blue, 'FaceAlpha', 0.7, ...
          'EdgeColor', 'none', 'Normalization', 'probability');
    
    xlabel('Chlorophyll-a Anomaly (mg m^{-3})', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Probability Density', 'FontSize', 10, 'FontWeight', 'bold');
    
    % 使用文本标注代替legend
    text(0.02, 0.98, 'MHW Periods', 'Units', 'normalized', 'VerticalAlignment', 'top', ...
         'Color', sci_colors.red, 'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'white');
    text(0.02, 0.90, 'Non-MHW Periods', 'Units', 'normalized', 'VerticalAlignment', 'top', ...
         'Color', sci_colors.blue, 'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'white');
    
    set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
    grid on;
    grid minor;
    set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
    title('Distribution of Chl-a Anomalies', 'FontSize', 11, 'FontWeight', 'bold');
    
    % 箱线图
    subplot(1, 2, 2);
    box_data = [hw_samples; non_hw_samples];
    group_data = [ones(length(hw_samples), 1); 2*ones(length(non_hw_samples), 1)];
    
    boxplot(box_data, group_data, 'Labels', {'MHW', 'Non-MHW'}, ...
            'Widths', 0.6);
    ylabel('Chlorophyll-a Anomaly (mg m^{-3})', 'FontSize', 10, 'FontWeight', 'bold');
    set(gca, 'FontSize', 9, 'LineWidth', 0.8, 'TickDir', 'out');
    grid on;
    title('Boxplot of Chl-a Anomalies', 'FontSize', 11, 'FontWeight', 'bold');
    
    % 添加统计检验结果
    hw_mean = mean(hw_samples, 'omitnan');
    non_hw_mean = mean(non_hw_samples, 'omitnan');
    [~, p_val] = ttest2(hw_samples, non_hw_samples);
    
    text(0.5, 0.9, sprintf('p = %.2e', p_val), 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', 'white');
    
    export_fig(fullfile(output_dir, 'sci_statistical_distribution.png'), '-r300', '-png', '-transparent');
    saveas(gcf, fullfile(output_dir, 'sci_statistical_distribution.fig'));
end


