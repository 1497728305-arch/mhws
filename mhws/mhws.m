%% 海洋热浪检测与时空特征分析（含季节热浪强度和持续时间分析）
% 使用1982-2024年OISST海温数据（按年份保存）
% 区域：东经110-180，北纬30-60
% 重点分析2015-2024年海洋热浪变化

clear all;
close all;
clc;

%% 1. 设置参数
data_dir = 'D:\dlb\m_mhw1.0-master\m_mhw1.0-master\data\global'; % 替换为您的数据目录
start_year = 1982;
end_year = 2024;
analysis_start_year = 2015;
analysis_end_year = 2024;

% 研究区域范围
lon_range = [110, 180];
lat_range = [30, 60];

% 海洋热浪定义参数
climatology_start_year = 1983; % 气候基准期开始年份
climatology_end_year = 2014;   % 气候基准期结束年份
percentile_threshold = 90; % 百分位阈值
min_duration = 5; % 最小持续天数

% 季节定义
seasons = {'Winter (DJF)', 'Spring (MAM)', 'Summer (JJA)', 'Fall (SON)'};
season_months = {[12, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11]};

% 降低空间分辨率以减少内存使用
spatial_downsample_factor = 2; % 每2个点取1个点



%% 2. 读取并预处理数据
disp('读取并预处理数据...');

% 获取所有数据文件
file_list = {};
for year = start_year:end_year
    filename = fullfile(data_dir, sprintf('sst.day.mean.%d.nc', year));
    if exist(filename, 'file') == 2
        file_list{end+1} = filename;
    else
        warning('文件不存在: %s', filename);
    end
end

if isempty(file_list)
    error('没有找到任何数据文件，请检查数据目录和文件名格式');
end

% 初始化变量
all_dates = [];
all_sst = [];

% 循环读取所有文件
for i = 1:length(file_list)
    filename = file_list{i};
    fprintf('读取文件: %s\n', filename);
    
    try
        % 读取时间变量并转换为日期
        time_var = ncread(filename, 'time');
        time_ref_str = ncreadatt(filename, 'time', 'units');
        
        % 解析时间参考
        if contains(time_ref_str, 'since')
            parts = strsplit(time_ref_str, 'since');
            ref_date_str = strtrim(parts{2});
            
            % 处理不同的日期格式
            if contains(ref_date_str, '-')
                time_ref = datenum(ref_date_str);
            else
                time_ref = datenum(1800, 1, 1); % 默认参考日期
            end
        else
            time_ref = datenum(1800, 1, 1); % 默认参考日期
        end
        
        % 确保 time_var 是列向量
        time_var = time_var(:);
        file_dates = time_ref + time_var;
        
        % 读取SST数据
        sst_data = ncread(filename, 'sst');
        
        % 如果是第一个文件，提取研究区域
        if i == 1
            % 读取经纬度
            lon = ncread(filename, 'lon');
            lat = ncread(filename, 'lat');
            
            % 提取研究区域
            lat_idx = find(lat >= lat_range(1) & lat <= lat_range(2));
            lon_idx = find(lon >= lon_range(1) & lon <= lon_range(2));
            
            if isempty(lat_idx) || isempty(lon_idx)
                error('在研究区域范围内没有找到数据点，请检查经纬度范围');
            end
            
            % 降低空间分辨率
            lat_idx = lat_idx(1:spatial_downsample_factor:end);
            lon_idx = lon_idx(1:spatial_downsample_factor:end);
            
            lat_region = lat(lat_idx);
            lon_region = lon(lon_idx);
            
            % 初始化 all_sst
            all_sst = zeros(length(lon_idx), length(lat_idx), 0);
        end
        
        % 提取研究区域的SST数据
        sst_region = sst_data(lon_idx, lat_idx, :);
        
        % 合并数据
        all_dates = [all_dates; file_dates];
        all_sst = cat(3, all_sst, sst_region);
        
    catch ME
        warning('读取文件 %s 时出错: %s', filename, ME.message);
    end
end

if isempty(all_dates)
    error('没有成功读取任何数据');
end

% 确保日期是列向量
all_dates = all_dates(:);

%% 3. 计算气候基准期和阈值
disp('计算气候基准期和阈值...');

% 提取年份
try
    years_all = zeros(length(all_dates), 1);
    for i = 1:length(all_dates)
        date_vec = datevec(all_dates(i));
        years_all(i) = date_vec(1);
    end
catch ME
    error('无法从 all_dates 提取年份: %s', ME.message);
end

% 找到基准期的时间索引
baseline_idx = find(years_all >= climatology_start_year & years_all <= climatology_end_year);

if isempty(baseline_idx)
    error('在气候基准期 %d-%d 内没有找到数据', climatology_start_year, climatology_end_year);
end

% 计算每日气候态(均值)和阈值
clim_daily = zeros(length(lon_region), length(lat_region), 366);
clim_thresh = zeros(length(lon_region), length(lat_region), 366);

% 获取基准期的日期和SST数据
baseline_dates = all_dates(baseline_idx);
baseline_sst = all_sst(:, :, baseline_idx);

for d = 1:366
    % 找到基准期内每年的这一天
    day_of_year = zeros(length(baseline_dates), 1);
    for i = 1:length(baseline_dates)
        date_vec = datevec(baseline_dates(i));
        day_of_year(i) = floor(baseline_dates(i) - datenum(date_vec(1), 1, 1)) + 1;
    end
    
    day_idx = find(day_of_year == d);
    
    if ~isempty(day_idx)
        % 计算气候均值
        clim_daily(:, :, d) = nanmean(baseline_sst(:, :, day_idx), 3);
        
        % 计算百分位阈值
        for i = 1:length(lon_region)
            for j = 1:length(lat_region)
                sst_vals = squeeze(baseline_sst(i, j, day_idx));
                valid_vals = sst_vals(~isnan(sst_vals));
                if ~isempty(valid_vals)
                    clim_thresh(i, j, d) = prctile(valid_vals, percentile_threshold);
                else
                    clim_thresh(i, j, d) = NaN;
                end
            end
        end
    end
end

%% 4. 检测海洋热浪事件
disp('检测海洋热浪事件...');

% 提取分析期
analysis_idx = find(years_all >= analysis_start_year & years_all <= analysis_end_year);

if isempty(analysis_idx)
    error('在分析期 %d-%d 内没有找到数据', analysis_start_year, analysis_end_year);
end

dates_analysis = all_dates(analysis_idx);
sst_analysis = all_sst(:, :, analysis_idx);

[nlon, nlat, ntime] = size(sst_analysis);

% 初始化热浪指标
mhw_mask = false(nlon, nlat, ntime); % 热浪发生与否
mhw_intensity = zeros(nlon, nlat, ntime); % 热浪强度

% 计算SSTA和检测热浪
for t = 1:ntime
    current_date = dates_analysis(t);
    date_vec = datevec(current_date);
    year_val = date_vec(1);
    doy = floor(current_date - datenum(year_val, 1, 1)) + 1;
    
    if doy > 366 % 处理闰年
        doy = 366;
    end
    
    % 计算海温异常
    ssta = sst_analysis(:, :, t) - clim_daily(:, :, doy);
    
    % 检测是否超过阈值
    exceeds_thresh = sst_analysis(:, :, t) > clim_thresh(:, :, doy);
    
    % 存储结果
    mhw_mask(:, :, t) = exceeds_thresh;
    mhw_intensity(:, :, t) = ssta .* double(exceeds_thresh);
end

%% 5. 计算热浪指标的时间序列
disp('计算热浪指标时间序列...');

% 计算区域平均的热浪天数比例
mhw_fraction = zeros(ntime, 1);
for t = 1:ntime
    mhw_fraction(t) = nanmean(nanmean(mhw_mask(:, :, t)));
end

% 按年聚合
years_analysis = zeros(ntime, 1);
for t = 1:ntime
    date_vec = datevec(dates_analysis(t));
    years_analysis(t) = date_vec(1);
end

unique_years = unique(years_analysis);
yearly_mhw_days = zeros(length(unique_years), 1);

for y = 1:length(unique_years)
    year_idx = (years_analysis == unique_years(y));
    yearly_mhw_days(y) = sum(mhw_fraction(year_idx));
end

%% 6. 计算热浪指标的空间分布
disp('计算热浪指标空间分布...');

% 总热浪天数
total_mhw_days = sum(mhw_mask, 3);

% 平均热浪强度(只计算热浪发生时的平均强度)
mhw_intensity_sum = sum(mhw_intensity, 3);
mean_mhw_intensity = mhw_intensity_sum ./ total_mhw_days;
mean_mhw_intensity(isnan(mean_mhw_intensity)) = 0;

%% 7. 详细的季节变化分析
disp('进行详细的季节变化分析...');

% 提取月份信息
months_analysis = zeros(ntime, 1);
for t = 1:ntime
    date_vec = datevec(dates_analysis(t));
    months_analysis(t) = date_vec(2);
end

% 初始化季节热浪指标
seasonal_mhw_days = zeros(nlon, nlat, 4); % 每个季节的总热浪天数
seasonal_mhw_intensity = zeros(nlon, nlat, 4); % 每个季节的平均热浪强度
seasonal_mhw_duration = zeros(nlon, nlat, 4); % 每个季节的平均热浪持续时间
seasonal_mhw_freq = zeros(4, length(unique_years)); % 每个季节每年的热浪频率
seasonal_mhw_intensity_ts = zeros(4, length(unique_years)); % 每个季节每年的热浪强度
seasonal_mhw_duration_ts = zeros(4, length(unique_years)); % 每个季节每年的热浪持续时间

% 按季节分析
for s = 1:4
    % 获取当前季节的月份
    season_months_list = season_months{s};
    
    % 找到当前季节的所有时间点
    if s == 1 % 冬季 (DJF) - 需要跨年处理
        % 创建一个新的季节索引，正确处理跨年
        season_idx = [];
        for y = 1:length(unique_years)
            current_year = unique_years(y);
            
            % 找到当前年份的12月
            dec_idx = find(years_analysis == current_year & months_analysis == 12);
            
            % 找到下一年份的1月和2月
            next_year = current_year + 1;
            if next_year <= max(unique_years)
                jan_feb_idx = find(years_analysis == next_year & ismember(months_analysis, [1, 2]));
            else
                jan_feb_idx = [];
            end
            
            % 组合成一个完整的冬季
            if ~isempty(dec_idx) && ~isempty(jan_feb_idx)
                season_idx = [season_idx; dec_idx; jan_feb_idx];
            end
        end
    else
        % 对于其他季节，直接找到对应的月份
        season_idx = find(ismember(months_analysis, season_months_list));
    end
    
    if isempty(season_idx)
        warning('季节 %d 没有找到数据', s);
        continue;
    end
    
    % 计算当前季节的热浪天数
    seasonal_mhw_days(:, :, s) = sum(mhw_mask(:, :, season_idx), 3);
    
    % 计算当前季节的热浪强度
    season_intensity_sum = sum(mhw_intensity(:, :, season_idx), 3);
    seasonal_mhw_intensity(:, :, s) = season_intensity_sum ./ max(seasonal_mhw_days(:, :, s), 1);
    seasonal_mhw_intensity(isnan(seasonal_mhw_intensity)) = 0;
    
    % 计算当前季节的热浪持续时间
    for i = 1:nlon
        for j = 1:nlat
            % 提取当前网格点的时间序列
            ts_mask = squeeze(mhw_mask(i, j, season_idx));
            
            % 计算连续热浪事件的持续时间
            events = bwlabel(ts_mask); % 标记连续事件
            if max(events) > 0
                durations = zeros(max(events), 1);
                for e = 1:max(events)
                    durations(e) = sum(events == e);
                end
                seasonal_mhw_duration(i, j, s) = mean(durations);
            else
                seasonal_mhw_duration(i, j, s) = 0;
            end
        end
    end
    
    % 计算每年的季节热浪频率、强度和持续时间
    for y = 1:length(unique_years)
        current_year = unique_years(y);
        
        if s == 1 % 冬季需要特殊处理
            % 对于冬季，年份指的是冬季结束的年份
            % 例如，2015年冬季包括2014年12月和2015年1-2月
            if y > 1 % 从第二个年份开始
                prev_year = unique_years(y-1);
                
                % 找到前一年12月
                dec_idx = find(years_analysis == prev_year & months_analysis == 12);
                % 找到当前年1-2月
                jan_feb_idx = find(years_analysis == current_year & ismember(months_analysis, [1, 2]));
                
                year_season_idx = [dec_idx; jan_feb_idx];
                
                if ~isempty(year_season_idx)
                    % 计算频率
                    seasonal_mhw_freq(s, y) = mean(mean(mhw_mask(:, :, year_season_idx), 'all', 'omitnan'));
                    
                    % 计算强度
                    intensity_values = mhw_intensity(:, :, year_season_idx);
                    intensity_values(intensity_values == 0) = NaN; % 将0值转换为NaN
                    seasonal_mhw_intensity_ts(s, y) = nanmean(intensity_values(:));
                    
                    % 计算持续时间
                    duration_values = zeros(nlon, nlat);
                    for i = 1:nlon
                        for j = 1:nlat
                            ts_mask = squeeze(mhw_mask(i, j, year_season_idx));
                            events = bwlabel(ts_mask);
                            if max(events) > 0
                                durations = zeros(max(events), 1);
                                for e = 1:max(events)
                                    durations(e) = sum(events == e);
                                end
                                duration_values(i, j) = mean(durations);
                            else
                                duration_values(i, j) = 0;
                            end
                        end
                    end
                    seasonal_mhw_duration_ts(s, y) = nanmean(duration_values(:));
                end
            end
        else
            % 对于其他季节，直接找到对应年份的月份
            year_season_idx = season_idx(years_analysis(season_idx) == current_year);
            if ~isempty(year_season_idx)
                % 计算频率
                seasonal_mhw_freq(s, y) = mean(mean(mhw_mask(:, :, year_season_idx), 'all', 'omitnan'));
                
                % 计算强度
                intensity_values = mhw_intensity(:, :, year_season_idx);
                intensity_values(intensity_values == 0) = NaN; % 将0值转换为NaN
                seasonal_mhw_intensity_ts(s, y) = nanmean(intensity_values(:));
                
                % 计算持续时间
                duration_values = zeros(nlon, nlat);
                for i = 1:nlon
                    for j = 1:nlat
                        ts_mask = squeeze(mhw_mask(i, j, year_season_idx));
                        events = bwlabel(ts_mask);
                        if max(events) > 0
                            durations = zeros(max(events), 1);
                            for e = 1:max(events)
                                durations(e) = sum(events == e);
                            end
                            duration_values(i, j) = mean(durations);
                        else
                            duration_values(i, j) = 0;
                        end
                    end
                end
                seasonal_mhw_duration_ts(s, y) = nanmean(duration_values(:));
            end
        end
    end
end

% 计算季节循环（月平均热浪频率）
monthly_mhw_freq = zeros(12, 1);
for m = 1:12
    month_idx = find(months_analysis == m);
    if ~isempty(month_idx)
        monthly_mhw_freq(m) = mean(mean(mean(mhw_mask(:, :, month_idx), 1, 'omitnan'), 2, 'omitnan'));
    end
end

%% 8. EOF分析 - 针对热浪强度场（使用更高效的方法）
disp('进行EOF分析...');

% 准备EOF分析数据 - 使用月平均热浪强度
monthly_dates = dates_analysis(1):30:dates_analysis(end);
if length(monthly_dates) > ntime
    monthly_dates = monthly_dates(1:ntime);
end

monthly_mhw_intensity = zeros(nlon, nlat, length(monthly_dates));

for m = 1:length(monthly_dates)
    month_start = monthly_dates(m);
    month_end = addtodate(month_start, 1, 'month');
    month_idx = find(dates_analysis >= month_start & dates_analysis < month_end);
    
    if ~isempty(month_idx)
        monthly_mhw_intensity(:, :, m) = nanmean(mhw_intensity(:, :, month_idx), 3);
    end
end

% 使用更高效的SVD方法进行EOF分析，避免构建大型协方差矩阵
disp('使用SVD方法进行EOF分析...');
[nx, ny, nt_eof] = size(monthly_mhw_intensity);

% 重塑数据为2D矩阵(空间点 x 时间)
X = reshape(monthly_mhw_intensity, nx*ny, nt_eof)';
X(isnan(X)) = 0; % 处理缺失值

% 去除时间均值
X_mean = mean(X, 1);
X_anom = X - repmat(X_mean, size(X, 1), 1);

% 使用经济型SVD分解，只计算前几个模态
num_modes = min(10, min(size(X_anom))); % 只计算前10个模态
[U, S, V] = svd(X_anom, 'econ');

% 提取前几个模态
U = U(:, 1:num_modes);
S = S(1:num_modes, 1:num_modes);
V = V(:, 1:num_modes);

% 计算方差解释率
eigenvalues = diag(S).^2 / (nt_eof - 1);
total_variance = sum(eigenvalues);
variance_explained = eigenvalues / total_variance;

% 计算主成分
PCs = U * S;

% 重塑EOF为空间模式
EOF1 = reshape(V(:, 1), nx, ny);
EOF2 = reshape(V(:, 2), nx, ny);
EOF3 = reshape(V(:, 3), nx, ny);

%% 海洋热浪检测与时空特征分析（优化空间分布可视化）
% 使用1982-2024年OISST海温数据（按年份保存）
% 区域：东经110-180，北纬30-60
% 重点分析2015-2024年海洋热浪变化

% [前面的数据读取和处理代码保持不变]

%% 9. Optimized Visualization Results
%% 9. Optimized Visualization Results
disp('Generating optimized visualization results...');

% Set unified color schemes
ocean_color = [0.7 0.9 1]; % Ocean color
land_color = [0.9 0.9 0.7]; % Land color
mhw_colormap = flipud(hot(256)); 
anomaly_colormap = redblue(256);
duration_colormap = flipud(hot(256));

% Set font sizes
title_fontsize = 16;
label_fontsize = 14;
axis_fontsize = 12;
legend_fontsize = 12;

% 辅助函数：使当前figure子图紧凑（减少空白）

% ========================== 9.1 总热浪天数空间分布 ==========================
fig1 = figure('Position', [100, 100, 1600, 800], 'Color', 'white', 'Name', 'Spatial Distribution of Marine Heatwaves');
set_tight_figure(fig1);
m_proj('mercator', 'long', [min(lon_region) max(lon_region)], 'lat', [min(lat_region) max(lat_region)]);
m_coast('patch', land_color, 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontsize', axis_fontsize, 'FontWeight', 'bold');
hold on;
[LON, LAT] = meshgrid(lon_region, lat_region);
h = m_pcolor(LON, LAT, total_mhw_days');
set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
colormap(mhw_colormap);
caxis([0 prctile(total_mhw_days(:), 95)]);
c = colorbar('eastoutside', 'FontSize', axis_fontsize);
c.Label.String = 'days';
c.Label.FontWeight = 'bold';
c.Label.FontSize = label_fontsize;
set(c, 'FontWeight', 'bold');
title(sprintf('Total Marine Heatwave Days (%d-%d)', analysis_start_year, analysis_end_year), ...
    'FontSize', title_fontsize, 'FontWeight', 'bold');
xlabel('Longitude', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Latitude', 'FontSize', label_fontsize, 'FontWeight', 'bold');
m_ruler(1.1, [0.1 0.9], 'ticklen', 0.01, 'fontsize', axis_fontsize);
m_northarrow(min(lon_region)+2, max(lat_region)-2, 1, 'type', 2);

% ========================== 9.2 平均热浪强度空间分布 ==========================
fig2 = figure('Position', [100, 100, 1600, 800], 'Color', 'white', 'Name', 'Spatial Distribution of Marine Heatwave Intensity');
set_tight_figure(fig2);
m_proj('mercator', 'long', [min(lon_region) max(lon_region)], 'lat', [min(lat_region) max(lat_region)]);
m_coast('patch', land_color, 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontsize', axis_fontsize, 'FontWeight', 'bold');
hold on;
h = m_pcolor(LON, LAT, mean_mhw_intensity');
set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
colormap(mhw_colormap);
caxis([0 prctile(mean_mhw_intensity(:), 95)]);
c = colorbar('eastoutside', 'FontSize', axis_fontsize);
c.Label.String = '°C';
c.Label.FontWeight = 'bold';
c.Label.FontSize = label_fontsize;
set(c, 'FontWeight', 'bold');
title(sprintf('Mean Marine Heatwave Intensity (%d-%d)', analysis_start_year, analysis_end_year), ...
    'FontSize', title_fontsize, 'FontWeight', 'bold');
xlabel('Longitude', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Latitude', 'FontSize', label_fontsize, 'FontWeight', 'bold');
m_ruler(1.1, [0.1 0.9], 'ticklen', 0.01, 'fontsize', axis_fontsize);
m_northarrow(min(lon_region)+2, max(lat_region)-2, 1, 'type', 2);

% ========================== 9.3 季节平均热浪强度（2×2子图） ==========================
% ========================== 9.3 季节平均热浪强度（2×2子图） ==========================
fig3 = figure('Position', [100, 100, 1600, 1000], 'Color', 'white', 'Name', 'Spatial Distribution of Seasonal Marine Heatwave Intensity');
set_tight_figure(fig3);
subpos = {[0.08, 0.55, 0.40, 0.35], [0.52, 0.55, 0.40, 0.35], ...
          [0.08, 0.08, 0.40, 0.35], [0.52, 0.08, 0.40, 0.35]};
for s = 1:4
    subplot('Position', subpos{s});
    m_proj('mercator', 'long', [min(lon_region) max(lon_region)], 'lat', [min(lat_region) max(lat_region)]);
    m_coast('patch', land_color, 'edgecolor', 'k');
    m_grid('box', 'fancy', 'tickdir', 'in', 'fontsize', axis_fontsize, 'FontWeight', 'bold');
    hold on;
    h = m_pcolor(LON, LAT, seasonal_mhw_intensity(:, :, s)');
    set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    colormap(mhw_colormap);
    caxis([0 prctile(seasonal_mhw_intensity(:), 95)]);
    
    % 创建垂直色标（右侧）
    c = colorbar('eastoutside', 'FontSize', axis_fontsize);
    set(c, 'FontWeight', 'bold');      % 色标刻度数字加粗
    c.Label.String = '';               % 隐藏默认标签
    drawnow;                           % 确保色标位置已更新
    c_pos = get(c, 'Position');        % [left, bottom, width, height] 归一化坐标
    
    % 使用 annotation 在色标正上方添加单位（不进入绘图区）
    annotation('textbox', [c_pos(1)+c_pos(3)/2, c_pos(2)+c_pos(4)+0.008, 0, 0], ...
        'String', '°C', 'FitBoxToText', 'on', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', label_fontsize, 'FontWeight', 'bold');
    
    title(sprintf('%s Intensity', seasons{s}), 'FontSize', title_fontsize, 'FontWeight', 'bold');
    set(gca, 'FontWeight', 'bold');    % 确保坐标轴文字（包括经纬度）加粗
end
% 全局强制所有文本加粗（防止遗漏）
set(findall(fig3, 'Type', 'Text'), 'FontWeight', 'bold');
sgtitle('Spatial Distribution of Seasonal Marine Heatwave Intensity', 'FontSize', 18, 'FontWeight', 'bold');

% ========================== 9.4 季节平均热浪持续时间（2×2子图） ==========================
fig4 = figure('Position', [100, 100, 1600, 1000], 'Color', 'white', 'Name', 'Spatial Distribution of Seasonal Marine Heatwave Duration');
set_tight_figure(fig4);
subpos = {[0.08, 0.55, 0.40, 0.35], [0.52, 0.55, 0.40, 0.35], ...
          [0.08, 0.08, 0.40, 0.35], [0.52, 0.08, 0.40, 0.35]};
for s = 1:4
    subplot('Position', subpos{s});
    m_proj('mercator', 'long', [min(lon_region) max(lon_region)], 'lat', [min(lat_region) max(lat_region)]);
    m_coast('patch', land_color, 'edgecolor', 'k');
    m_grid('box', 'fancy', 'tickdir', 'in', 'fontsize', axis_fontsize, 'FontWeight', 'bold');
    hold on;
    h = m_pcolor(LON, LAT, seasonal_mhw_duration(:, :, s)');
    set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    colormap(duration_colormap);
    caxis([0 prctile(seasonal_mhw_duration(:), 95)]);
    
    c = colorbar('eastoutside', 'FontSize', axis_fontsize);
    set(c, 'FontWeight', 'bold');
    c.Label.String = '';
    drawnow;
    c_pos = get(c, 'Position');
    annotation('textbox', [c_pos(1)+c_pos(3)/2, c_pos(2)+c_pos(4)+0.008, 0, 0], ...
        'String', 'days', 'FitBoxToText', 'on', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', label_fontsize, 'FontWeight', 'bold');
    
    title(sprintf('%s Duration', seasons{s}), 'FontSize', title_fontsize, 'FontWeight', 'bold');
    set(gca, 'FontWeight', 'bold');
end
set(findall(fig4, 'Type', 'Text'), 'FontWeight', 'bold');
sgtitle('Spatial Distribution of Seasonal Marine Heatwave Duration', 'FontSize', 18, 'FontWeight', 'bold');
% ========================== 9.5 时间序列分析（2×2子图） ==========================
fig5 = figure('Position', [100, 100, 1600, 1000], 'Color', 'white', 'Name', 'Time Series Analysis');
set_tight_figure(fig5);
% 手动定义2×2子图位置
subpos = {[0.08, 0.55, 0.40, 0.35], [0.52, 0.55, 0.40, 0.35], ...
          [0.08, 0.08, 0.40, 0.35], [0.52, 0.08, 0.40, 0.35]};

% 子图1：年际变化
subplot('Position', subpos{1});
plot(unique_years, yearly_mhw_days, 'o-', 'LineWidth', 2.5, 'MarkerSize', 8, ...
    'MarkerFaceColor', [0.2 0.6 0.8], 'Color', [0.2 0.4 0.8]);
xlabel('Year', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Marine Heatwave Days', 'FontSize', label_fontsize, 'FontWeight', 'bold');
title('Interannual Variation of Total MHW Days', 'FontSize', title_fontsize, 'FontWeight', 'bold');
grid on; box on;
set(gca, 'FontSize', axis_fontsize, 'FontWeight', 'bold');

% 子图2：季节循环
subplot('Position', subpos{2});
bar(monthly_mhw_freq, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none', 'BarWidth', 0.8);
set(gca, 'XTickLabel', {'1','2','3','4','5','6','7','8','9','10','11','12'});
xlabel('Month', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Marine Heatwave Frequency', 'FontSize', label_fontsize, 'FontWeight', 'bold');
title('Seasonal Cycle of MHW Frequency', 'FontSize', title_fontsize, 'FontWeight', 'bold');
grid on; box on;
set(gca, 'FontSize', axis_fontsize, 'FontWeight', 'bold');

% 子图3：季节强度年际变化
subplot('Position', subpos{3});
colors = lines(4);
hold on;
for s = 1:4
    if s == 1
        plot_years = unique_years(2:end);
        plot_data = seasonal_mhw_intensity_ts(s, 2:end);
    else
        plot_years = unique_years;
        plot_data = seasonal_mhw_intensity_ts(s, 1:length(unique_years));
    end
    if ~isempty(plot_data) && length(plot_years) == length(plot_data)
        plot(plot_years, plot_data, 'o-', 'Color', colors(s,:), ...
            'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(s,:), ...
            'DisplayName', seasons{s});
    end
end
xlabel('Year', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Intensity (°C)', 'FontSize', label_fontsize, 'FontWeight', 'bold');
title('Interannual Variation of Seasonal MHW Intensity', 'FontSize', title_fontsize, 'FontWeight', 'bold');
legend('show', 'Location', 'best', 'FontSize', legend_fontsize, 'FontWeight', 'bold');
grid on; box on;
set(gca, 'FontSize', axis_fontsize, 'FontWeight', 'bold');

% 子图4：季节持续时间年际变化
subplot('Position', subpos{4});
hold on;
for s = 1:4
    if s == 1
        plot_years = unique_years(2:end);
        plot_data = seasonal_mhw_duration_ts(s, 2:end);
    else
        plot_years = unique_years;
        plot_data = seasonal_mhw_duration_ts(s, 1:length(unique_years));
    end
    if ~isempty(plot_data) && length(plot_years) == length(plot_data)
        plot(plot_years, plot_data, 'o-', 'Color', colors(s,:), ...
            'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(s,:), ...
            'DisplayName', seasons{s});
    end
end
xlabel('Year', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Duration (days)', 'FontSize', label_fontsize, 'FontWeight', 'bold');
title('Interannual Variation of Seasonal MHW Duration', 'FontSize', title_fontsize, 'FontWeight', 'bold');
legend('show', 'Location', 'best', 'FontSize', legend_fontsize, 'FontWeight', 'bold');
grid on; box on;
set(gca, 'FontSize', axis_fontsize, 'FontWeight', 'bold');

sgtitle('Temporal Variation Characteristics of Marine Heatwaves', 'FontSize', 18, 'FontWeight', 'bold');

% ========================== 9.6 EOF分析结果（2×2子图） ==========================
fig6 = figure('Position', [100, 100, 1600, 1000], 'Color', 'white', 'Name', 'EOF Analysis Results');
set_tight_figure(fig6);
subpos = {[0.08, 0.55, 0.40, 0.35], [0.52, 0.55, 0.40, 0.35], ...
          [0.08, 0.08, 0.40, 0.35], [0.52, 0.08, 0.40, 0.35]};

% EOF1 空间模态
subplot('Position', subpos{1});
m_proj('mercator', 'long', [min(lon_region) max(lon_region)], 'lat', [min(lat_region) max(lat_region)]);
m_coast('patch', land_color, 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontsize', axis_fontsize, 'FontWeight', 'bold');
hold on;
h = m_pcolor(LON, LAT, EOF1');
set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
colormap(anomaly_colormap);
caxis([-max(abs(EOF1(:))) max(abs(EOF1(:)))]);
c = colorbar('eastoutside', 'FontSize', axis_fontsize);
c.Label.String = 'Anomaly Intensity (no unit)';
c.Label.FontWeight = 'bold';
c.Label.FontSize = label_fontsize;
set(c, 'FontWeight', 'bold');
title(['EOF1 (Variance Explained: ', num2str(variance_explained(1)*100, '%.1f'), '%)'], ...
    'FontSize', title_fontsize, 'FontWeight', 'bold');

% EOF2 空间模态
subplot('Position', subpos{2});
m_proj('mercator', 'long', [min(lon_region) max(lon_region)], 'lat', [min(lat_region) max(lat_region)]);
m_coast('patch', land_color, 'edgecolor', 'k');
m_grid('box', 'fancy', 'tickdir', 'in', 'fontsize', axis_fontsize, 'FontWeight', 'bold');
hold on;
h = m_pcolor(LON, LAT, EOF2');
set(h, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
colormap(anomaly_colormap);
caxis([-max(abs(EOF2(:))) max(abs(EOF2(:)))]);
c = colorbar('eastoutside', 'FontSize', axis_fontsize);
c.Label.String = 'Anomaly Intensity (no unit)';
c.Label.FontWeight = 'bold';
c.Label.FontSize = label_fontsize;
set(c, 'FontWeight', 'bold');
title(['EOF2 (Variance Explained: ', num2str(variance_explained(2)*100, '%.1f'), '%)'], ...
    'FontSize', title_fontsize, 'FontWeight', 'bold');

% PC1 时间序列
subplot('Position', subpos{3});
plot(monthly_dates, PCs(:, 1), 'LineWidth', 2.5, 'Color', [0.2 0.4 0.8]);
datetick('x', 'yyyy', 'keeplimits');
title('PC1 Time Series', 'FontSize', title_fontsize, 'FontWeight', 'bold');
xlabel('Time', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Amplitude', 'FontSize', label_fontsize, 'FontWeight', 'bold');
grid on; box on;
set(gca, 'FontSize', axis_fontsize, 'FontWeight', 'bold');

% PC2 时间序列
subplot('Position', subpos{4});
plot(monthly_dates, PCs(:, 2), 'LineWidth', 2.5, 'Color', [0.8 0.4 0.2]);
datetick('x', 'yyyy', 'keeplimits');
title('PC2 Time Series', 'FontSize', title_fontsize, 'FontWeight', 'bold');
xlabel('Time', 'FontSize', label_fontsize, 'FontWeight', 'bold');
ylabel('Amplitude', 'FontSize', label_fontsize, 'FontWeight', 'bold');
grid on; box on;
set(gca, 'FontSize', axis_fontsize, 'FontWeight', 'bold');

sgtitle('EOF Analysis Results', 'FontSize', 18, 'FontWeight', 'bold');
%% 10. 保存结果和图形
disp('保存分析结果和图形...');
output_filename = sprintf('marine_heatwave_analysis_%d-%d.mat', analysis_start_year, analysis_end_year);
save(output_filename, ...
    'total_mhw_days', 'mean_mhw_intensity', ...
    'yearly_mhw_days', 'monthly_mhw_freq', ...
    'seasonal_mhw_days', 'seasonal_mhw_intensity', 'seasonal_mhw_duration', ...
    'seasonal_mhw_freq', 'seasonal_mhw_intensity_ts', 'seasonal_mhw_duration_ts', ...
    'U', 'S', 'V', 'variance_explained', ...
    'lon_region', 'lat_region', 'dates_analysis', 'seasons', ...
    '-v7.3'); % 使用v7.3格式支持大型数据集

% 保存图形
saveas(figure(1), 'mhw_spatial_distribution.png');
saveas(figure(2), 'mhw_intensity_distribution.png');
saveas(figure(3), 'mhw_seasonal_intensity.png');
saveas(figure(4), 'mhw_seasonal_duration.png');
saveas(figure(5), 'mhw_temporal_variation.png');
saveas(figure(6), 'mhw_eof_analysis.png');

disp('分析和图形保存完成！');

%% 辅助函数 - 创建红蓝色彩图
function cmap = redblue(m)
    if nargin < 1
        m = 64;
    end
    
    % 创建从蓝色到红色的色彩映射
    r = [0, 0, 0.5, 1, 1, 0.5];
    g = [0, 0.5, 1, 1, 0.5, 0];
    b = [0.5, 1, 1, 0.5, 0, 0];
    
    pos = linspace(0, 1, 6);
    xi = linspace(0, 1, m);
    
    cmap = [interp1(pos, r, xi)', interp1(pos, g, xi)', interp1(pos, b, xi)'];
end
function set_tight_figure(fig, margin)
    if nargin < 2, margin = 0.03; end
    set(fig, 'DefaultAxesLooseInset', [margin, margin, margin, margin]);
end
