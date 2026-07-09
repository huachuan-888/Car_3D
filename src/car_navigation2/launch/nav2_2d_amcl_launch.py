import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def generate_launch_description():
    # 1. 定位包路径
    car_navigation2_dir = get_package_share_directory('car_navigation2')
    nav2_bringup_dir = get_package_share_directory('nav2_bringup')
    
    # 2. 声明参数
    use_sim_time = LaunchConfiguration('use_sim_time', default='true') 
    nav2_param_path = LaunchConfiguration('params_file', default=os.path.join(car_navigation2_dir, 'param', 'car_nav2amcl_2d.yaml'))
    rviz_config_dir = os.path.join(car_navigation2_dir, 'rviz', 'nav2_gmap-lmap.rviz')
    map_yaml_path = os.path.join(car_navigation2_dir, 'maps', 'carto7.7_map.yaml')

    # 3. 启动 Nav2 Bringup (恢复开启自带的 map_server 和 amcl)
    nav2_bringup_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([nav2_bringup_dir, '/launch', '/bringup_launch.py']),
        launch_arguments={
            'map': map_yaml_path,
            'use_sim_time': use_sim_time,
            'params_file': nav2_param_path,
            'use_amcl': 'True',         # 【核心修改】重新启用 amcl
            'use_map_server': 'True',   # 【核心修改】重新启用 map_server
            'autostart': 'True'
        }.items(),
    )

    # 4. RViz2
    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        arguments=['-d', rviz_config_dir],
        parameters=[{'use_sim_time': use_sim_time}],
        output='screen'
    )
    
    return LaunchDescription([
        nav2_bringup_launch, 
        rviz_node
    ])