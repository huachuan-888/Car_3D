-- 离线重放bag、读取pbstream位姿图，拼接所有点云输出ply三维地图
options = {
  pipeline = {
    {action = "load_bag"},                -- 第一步：加载录制的rosbag2(.db3)
    {action = "load_pose_graph"},          -- 第二步：加载建图保存的pbstream优化位姿
    {
      action = "voxel_filter",
      voxel_size = 0.05,                  -- 0.05米体素降采样，平衡文件大小与精度
    },
    {action = "write_ply", filename = "car_3d_map.ply"}, -- 输出3D点云文件
  }
}
return options