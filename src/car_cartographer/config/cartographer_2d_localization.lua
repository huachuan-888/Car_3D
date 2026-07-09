-- Cartographer 2D Localization Configuration (使用先验地图) 纯定位模式
--：Cartographer 纯定位模式不是每帧直接拿激光和已加载 .pbstream 地图做实时 scan-to-map，它主要还是通过 pose graph 异步约束来修正 map -> odom。

--如果匹配不够及时，下一步就不是继续调 Cartographer，而是要换成真正实时的 scan-to-map 定位方案，比如 AMCL，或者单独加一个 ICP / correlative scan matcher 节点直接根据 /scan + map 发布 map -> odom。
-- 加载 Cartographer 默认建图器参数，下面只覆盖本定位场景需要调整的参数。
include "map_builder.lua"
-- 加载 Cartographer 默认轨迹构建参数，包括 2D/3D trajectory builder 默认值。
include "trajectory_builder.lua"

options = {
  -- 使用 map_builder.lua 中的全局 MAP_BUILDER 配置对象。
  map_builder = MAP_BUILDER,
  -- 使用 trajectory_builder.lua 中的全局 TRAJECTORY_BUILDER 配置对象。
  trajectory_builder = TRAJECTORY_BUILDER,
  -- 全局地图坐标系；加载的先验地图、定位结果都以该坐标系为基准。
  map_frame = "map",
  -- Cartographer 内部跟踪的机器人坐标系；需要能通过 TF 连接到雷达和 IMU。
  tracking_frame = "base_footprint",
  -- Cartographer 发布位姿/TF 的目标坐标系；这里用于发布 map -> odom 修正。
  published_frame = "odom",
  -- 里程计坐标系名称；与外部 odom 数据和 Nav2 使用的 odom frame 保持一致。
  odom_frame = "odom",
  -- false 表示不由 Cartographer 生成 odom -> base 的 TF，保留外部里程计/仿真发布。
  provide_odom_frame = false,
  -- 将发布的位姿投影到 2D 平面，去掉 z、roll、pitch，适合平面移动机器人。
  publish_frame_projected_to_2d = true,
  -- 使用位姿外推器在两帧雷达匹配之间预测位姿，提高发布频率和平滑性。
  use_pose_extrapolator = true,
  -- 订阅并使用 odom 作为运动预测先验，降低纯激光匹配抖动。
  use_odometry = true,
  -- 不使用 GPS/NavSat 数据。
  use_nav_sat = false,
  -- 不使用 landmark/人工路标约束。
  use_landmarks = false,
  -- 使用 1 路 LaserScan 输入，通常对应 /scan。
  num_laser_scans = 1,
  -- 不使用 MultiEchoLaserScan 输入。
  num_multi_echo_laser_scans = 0,
  -- 每帧 LaserScan 不再切分子帧；1 表示整帧一次处理。
  num_subdivisions_per_laser_scan = 1,
  -- 不使用 PointCloud2 点云输入。
  num_point_clouds = 0,
  -- 查询 TF 的最长等待时间，单位秒；过短可能丢数据，过长会增加延迟。
  lookup_transform_timeout_sec = 0.2,
  -- 发布 submap 列表/纹理的周期，单位秒；主要影响可视化和调试。
  submap_publish_period_sec = 0.3,
  -- 发布定位位姿的周期，单位秒；5e-3 表示约 200 Hz。
  pose_publish_period_sec = 5e-3,
  -- 发布轨迹点的周期，单位秒；主要用于可视化轨迹。
  trajectory_publish_period_sec = 30e-3,
  -- 雷达数据采样比例；1.0 表示使用全部雷达数据。
  rangefinder_sampling_ratio = 1.,
  -- 里程计数据采样比例；1.0 表示使用全部 odom 数据。
  odometry_sampling_ratio = 1.,
  -- 固定坐标系位姿数据采样比例；当前未启用 NavSat 时基本不会用到。
  fixed_frame_pose_sampling_ratio = 1.,
  -- 不使用 IMU；全向雷达 + odom 足够支撑平面定位，也避免 IMU 与 tracking_frame 不共点导致 fatal。
  imu_sampling_ratio = 0.,
  -- landmark 数据采样比例；当前 use_landmarks=false 时基本不会用到。
  landmarks_sampling_ratio = 1.,
}

-- 启用 2D trajectory builder，匹配平面激光定位场景。
MAP_BUILDER.use_trajectory_builder_2d = true
-- 关闭 3D trajectory builder，避免加载 3D SLAM 相关逻辑和参数。
MAP_BUILDER.use_trajectory_builder_3d = false
-- 后台约束构建线程数；提高后端匹配吞吐，减少每节点优化时的排队延迟。
MAP_BUILDER.num_background_threads = 8

-- 纯定位模式：先验地图由 cartographer_node 的 -load_state_filename 加载。
-- 这里限制在线新生成的子图数量，避免定位时不断扩图。
TRAJECTORY_BUILDER.pure_localization_trimmer = {
  -- 纯定位时最多保留的在线子图数量；越小越省资源，也越不容易把定位过程变成继续建图。
  max_submaps_to_keep = 3,
}

-- 定位模式参数
-- 每个 2D 子图累计的雷达帧数；定位阶段适当减小，让在线定位子图更快参与匹配和修正。
TRAJECTORY_BUILDER_2D.submaps.num_range_data = 25
-- 雷达有效最小距离，单位米；小于该距离的点会被忽略，避免车体或近处噪声干扰。
TRAJECTORY_BUILDER_2D.min_range = 0.10
-- 雷达有效最大距离，单位米；增大可使用更远墙面/结构做地图匹配。
TRAJECTORY_BUILDER_2D.max_range = 8.0
-- 无有效回波时用于清空 free space 的射线长度，单位米。
TRAJECTORY_BUILDER_2D.missing_data_ray_length = 8.0
-- 每次匹配累计的雷达帧数；1 表示每帧雷达都独立参与一次匹配。
TRAJECTORY_BUILDER_2D.num_accumulated_range_data = 1
-- 运动过滤阈值；进一步减小节点间隔，让小位移也能尽快进入后端匹配。
TRAJECTORY_BUILDER_2D.motion_filter.max_time_seconds = 0.1
TRAJECTORY_BUILDER_2D.motion_filter.max_distance_meters = 0.03
TRAJECTORY_BUILDER_2D.motion_filter.max_angle_radians = math.rad(0.2)
-- 使用全向雷达和 odom 做 2D 定位，不订阅 IMU。
TRAJECTORY_BUILDER_2D.use_imu_data = false
-- 启用实时相关性扫描匹配，先在局部窗口粗搜索，再交给 Ceres 精配准。
TRAJECTORY_BUILDER_2D.use_online_correlative_scan_matching = true

-- 小窗口实时匹配：前端每帧在预测位姿附近寻找更贴地图的位置。
-- 实时匹配的平移搜索窗口，单位米；0.20 表示允许每帧在 20 cm 内做连续纠偏。
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.linear_search_window = 0.20
-- 实时匹配的角度搜索窗口；math.rad(8.) 表示正负约 8 度范围。
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.angular_search_window = math.rad(8.)
-- 平移偏离预测位姿的惩罚权重；适度降低，让实时匹配能更主动修正位置。
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.translation_delta_cost_weight = 5.
-- 旋转偏离预测位姿的惩罚权重；适度降低，让实时匹配能更主动修正姿态。
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.rotation_delta_cost_weight = 2.
-- Ceres 扫描匹配中占据栅格匹配权重；提高激光点与局部栅格的贴合优先级。
TRAJECTORY_BUILDER_2D.ceres_scan_matcher.occupied_space_weight = 110.
-- Ceres 扫描匹配中平移先验权重；降低后更容易做实时小幅位置拉回。
TRAJECTORY_BUILDER_2D.ceres_scan_matcher.translation_weight = 10.
-- Ceres 扫描匹配中旋转先验权重；降低后更容易做实时小幅姿态拉回。
TRAJECTORY_BUILDER_2D.ceres_scan_matcher.rotation_weight = 10.

-- 图优化：只做高置信小范围约束，避免后端把定位结果大幅拉跳。
-- 优化问题的 Huber 鲁棒核尺度；用于降低异常残差对整体优化的影响。
POSE_GRAPH.optimization_problem.huber_scale = 1e1
-- 降低本地 SLAM 位姿残差权重，让先验地图约束能更快拉回累计误差。
POSE_GRAPH.optimization_problem.local_slam_pose_translation_weight = 5e4
POSE_GRAPH.optimization_problem.local_slam_pose_rotation_weight = 5e4
-- 每累计多少个节点执行一次 pose graph 优化；1 表示每个节点都触发优化，尽量实时纠偏。
POSE_GRAPH.optimize_every_n_nodes = 1
-- 约束构建采样比例；1.0 表示每个候选节点都尝试局部约束。
POSE_GRAPH.constraint_builder.sampling_ratio = 1.0
-- 局部约束搜索的最大距离，单位米；收紧到 0.3m，只允许非常近的子图纠偏。
POSE_GRAPH.constraint_builder.max_constraint_distance = 0.3
-- 局部约束接受的最低匹配分数；适度放宽，让 0.3m 内的有效匹配能更快生效。
POSE_GRAPH.constraint_builder.min_score = 0.84
-- 全局重定位约束接受的最低匹配分数；通常比 min_score 更高以避免误定位。
POSE_GRAPH.constraint_builder.global_localization_min_score = 0.99
-- pose graph 快速相关性匹配的平移搜索窗口，单位米；与 0.3m 约束半径保持一致。
POSE_GRAPH.constraint_builder.fast_correlative_scan_matcher.linear_search_window = 0.30
-- pose graph 快速相关性匹配的角度搜索窗口；math.rad(8.) 表示正负约 8 度。
POSE_GRAPH.constraint_builder.fast_correlative_scan_matcher.angular_search_window = math.rad(8.)
-- 约束精配准 Ceres 阶段的占据栅格权重；越大越重视地图/雷达重合度。
POSE_GRAPH.constraint_builder.ceres_scan_matcher.occupied_space_weight = 35.
-- 约束精配准 Ceres 阶段的平移先验权重；降低后地图约束能更快拉回位置。
POSE_GRAPH.constraint_builder.ceres_scan_matcher.translation_weight = 6.
-- 约束精配准 Ceres 阶段的旋转先验权重；降低后地图约束能更快拉回姿态。
POSE_GRAPH.constraint_builder.ceres_scan_matcher.rotation_weight = 2.
-- 全局约束搜索的采样比例；关闭全局重定位抽样，避免定位过程中跨区域拉跳。
POSE_GRAPH.global_sampling_ratio = 0.
-- 距离上次全局约束搜索至少等待的时间，单位秒；全局抽样已关闭，此处只作保险。
POSE_GRAPH.global_constraint_search_after_n_seconds = 1e9
-- pose graph 优化中 odom 平移残差权重；适度放松，让地图约束能够及时修正位置。
POSE_GRAPH.optimization_problem.odometry_translation_weight = 8e4
-- pose graph 优化中 odom 旋转残差权重；适度放松，让地图约束能够及时修正姿态。
POSE_GRAPH.optimization_problem.odometry_rotation_weight = 1e5

return options
