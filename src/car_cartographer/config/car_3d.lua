include "map_builder.lua"
include "trajectory_builder.lua"

options = {
  map_builder = MAP_BUILDER,
  trajectory_builder = TRAJECTORY_BUILDER,
  map_frame = "map",
  tracking_frame = "base_link",
  published_frame = "odom",
  odom_frame = "odom",
  provide_odom_frame = false,
  publish_frame_projected_to_2d = true, 
  
  use_odometry = true,
  use_nav_sat = false,
  use_landmarks = false,

  num_laser_scans = 1,
  num_multi_echo_laser_scans = 0,
  num_subdivisions_per_laser_scan = 1,
  num_point_clouds = 1,
  
  lookup_transform_timeout_sec = 5.0, 
  submap_publish_period_sec = 2.0,
  pose_publish_period_sec = 50e-3,
  trajectory_publish_period_sec = 100e-3,
  
  -- 【救命绝杀！！！】暴力抽帧！
  -- 设为 0.2 意味着：相机每发来 5 帧 3D 点云，算法直接扔掉 4 帧，只算 1 帧！
  -- 这将直接把 CPU 负载砍掉 80%，彻底消灭转弯时的卡顿！
  rangefinder_sampling_ratio = 0.2,
  
  odometry_sampling_ratio = 1.,
  fixed_frame_pose_sampling_ratio = 1.,
  imu_sampling_ratio = 1.,
  landmarks_sampling_ratio = 1.,
}

MAP_BUILDER.use_trajectory_builder_3d = true
MAP_BUILDER.use_trajectory_builder_2d = false

TRAJECTORY_BUILDER_3D.num_accumulated_range_data = 1
TRAJECTORY_BUILDER_3D.min_range = 0.3
TRAJECTORY_BUILDER_3D.max_range = 5.0

-- 保持 0.4 的马赛克画质，这是虚拟机不崩溃的底线
TRAJECTORY_BUILDER_3D.voxel_filter_size = 0.4
TRAJECTORY_BUILDER_3D.submaps.high_resolution = 0.25
TRAJECTORY_BUILDER_3D.submaps.low_resolution = 0.55

TRAJECTORY_BUILDER_3D.imu_gravity_time_constant = 10.0

-- 彻底关闭所有耗费 CPU 的高级搜索
TRAJECTORY_BUILDER_3D.use_online_correlative_scan_matching = false
TRAJECTORY_BUILDER_3D.ceres_scan_matcher.ceres_solver_options.max_num_iterations = 4
POSE_GRAPH.optimize_every_n_nodes = 60

POSE_GRAPH.constraint_builder.min_score = 0.65
POSE_GRAPH.constraint_builder.global_localization_min_score = 0.7

return options