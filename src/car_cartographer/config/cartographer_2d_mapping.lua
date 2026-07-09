-- Cartographer 2D Mapping 专业建图配置（优化长直道横向漂移）
-- 适配室内激光小车，odom+2D激光，无IMU，大范围闭环优化，完整保留所有行走区域
-- 建图完成后调用 /cartographer/save_map 生成永久地图文件，后续切换定位lua加载使用
-- 缺点 长距离管道直线行驶会飘逸
include "map_builder.lua"
include "trajectory_builder.lua"

options = {
  map_builder = MAP_BUILDER,
  trajectory_builder = TRAJECTORY_BUILDER,
  map_frame = "map",
  tracking_frame = "base_footprint",
  published_frame = "odom",
  odom_frame = "odom",
  provide_odom_frame = false,
  publish_frame_projected_to_2d = true,
  use_pose_extrapolator = true,
  use_odometry = true,
  use_nav_sat = false,
  use_landmarks = false,
  num_laser_scans = 1,
  num_multi_echo_laser_scans = 0,
  num_subdivisions_per_laser_scan = 1,
  num_point_clouds = 0,
  lookup_transform_timeout_sec = 0.2,
  submap_publish_period_sec = 0.3,
  pose_publish_period_sec = 5e-3,
  trajectory_publish_period_sec = 30e-3,
  rangefinder_sampling_ratio = 1.,
  odometry_sampling_ratio = 1.,
  fixed_frame_pose_sampling_ratio = 1.,
  imu_sampling_ratio = 0.,
  landmarks_sampling_ratio = 1.,
}

MAP_BUILDER.use_trajectory_builder_2d = true
MAP_BUILDER.use_trajectory_builder_3d = false
MAP_BUILDER.num_background_threads = 8

-- 无纯定位裁剪，完整保存全局地图
-- TRAJECTORY_BUILDER.pure_localization_trimmer = { max_submaps_to_keep = 3, }

TRAJECTORY_BUILDER_2D.submaps.num_range_data = 60
TRAJECTORY_BUILDER_2D.min_range = 0.10
TRAJECTORY_BUILDER_2D.max_range = 3.5
TRAJECTORY_BUILDER_2D.missing_data_ray_length = 3.5
TRAJECTORY_BUILDER_2D.num_accumulated_range_data = 1

-- 【修改1】缩小运动过滤阈值，微小位移立刻匹配，防止误差堆积
TRAJECTORY_BUILDER_2D.motion_filter.max_time_seconds = 0.05
TRAJECTORY_BUILDER_2D.motion_filter.max_distance_meters = 0.01
TRAJECTORY_BUILDER_2D.motion_filter.max_angle_radians = math.rad(0.05)

TRAJECTORY_BUILDER_2D.use_imu_data = false
TRAJECTORY_BUILDER_2D.use_online_correlative_scan_matching = true

-- 【修改2】放大前端实时匹配窗口，长直道可一次性修正大横向偏移
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.linear_search_window = 0.80
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.angular_search_window = math.rad(15.)
-- 【修改3】降低里程先验惩罚，允许激光大幅修正横向打滑偏移
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.translation_delta_cost_weight = 1.0
TRAJECTORY_BUILDER_2D.real_time_correlative_scan_matcher.rotation_delta_cost_weight = 1.0
TRAJECTORY_BUILDER_2D.ceres_scan_matcher.occupied_space_weight = 120.
-- 【修改4】降低Ceres里程权重，地图约束优先
TRAJECTORY_BUILDER_2D.ceres_scan_matcher.translation_weight = 2.0
TRAJECTORY_BUILDER_2D.ceres_scan_matcher.rotation_weight = 2.0

POSE_GRAPH.optimization_problem.huber_scale = 1e1
POSE_GRAPH.optimization_problem.local_slam_pose_translation_weight = 8000
POSE_GRAPH.optimization_problem.local_slam_pose_rotation_weight = 8000
POSE_GRAPH.optimize_every_n_nodes = 2
POSE_GRAPH.constraint_builder.sampling_ratio = 1.0
POSE_GRAPH.constraint_builder.max_constraint_distance = 10.0
POSE_GRAPH.constraint_builder.min_score = 0.65
POSE_GRAPH.constraint_builder.global_localization_min_score = 0.85
POSE_GRAPH.constraint_builder.fast_correlative_scan_matcher.linear_search_window = 10.0
POSE_GRAPH.constraint_builder.fast_correlative_scan_matcher.angular_search_window = math.rad(15.)
POSE_GRAPH.constraint_builder.ceres_scan_matcher.occupied_space_weight = 40.
POSE_GRAPH.constraint_builder.ceres_scan_matcher.translation_weight = 5.
POSE_GRAPH.constraint_builder.ceres_scan_matcher.rotation_weight = 2.5
POSE_GRAPH.global_sampling_ratio = 0.3
POSE_GRAPH.global_constraint_search_after_n_seconds = 15.0

-- 【修改5】大幅降低odom权重，削弱轮子里程计可信度，激光地图主导定位
POSE_GRAPH.optimization_problem.odometry_translation_weight = 800
POSE_GRAPH.optimization_problem.odometry_rotation_weight = 800

return options