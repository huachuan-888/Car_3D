import os
from launch import LaunchDescription
from launch.substitutions import LaunchConfiguration
from launch.actions import TimerAction
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    pkg_share = FindPackageShare(package='car_cartographer').find('car_cartographer')
    
    use_sim_time = LaunchConfiguration('use_sim_time', default='true')
    resolution = LaunchConfiguration('resolution', default='0.05')
    publish_period_sec = LaunchConfiguration('publish_period_sec', default='1.0')
    
    configuration_directory = LaunchConfiguration('configuration_directory',default= os.path.join(pkg_share, 'config') )
    configuration_basename = LaunchConfiguration('configuration_basename', default='car_3d.lua')

    cartographer_node = Node(
        package='cartographer_ros',
        executable='cartographer_node',
        name='cartographer_node',
        output='screen',
        parameters=[{'use_sim_time': use_sim_time}],
        arguments=[
            '-configuration_directory', configuration_directory,
            '-configuration_basename', configuration_basename
        ],
        # 改动：注释imu映射，不接收IMU消息，绕开3D IMU原点校验崩溃
        remappings=[
            ("points2", "/depth_camera/points"),
            ("imu", "/imu/data"),
            ("scan", "/scan")
        ]
    )

    cartographer_occupancy_grid_node = Node(
        package='cartographer_ros',
        executable='cartographer_occupancy_grid_node',
        name='cartographer_occupancy_grid_node',
        output='screen',
        parameters=[{'use_sim_time': use_sim_time}],
        arguments=['-resolution', resolution, '-publish_period_sec', publish_period_sec]
    )

    try:
        rviz_pkg = FindPackageShare(package='car_description').find('car_description')
        rviz_config = os.path.join(rviz_pkg, 'rviz', 'ld_depth.rviz')
    except Exception:
        rviz_config = None

    if rviz_config and os.path.exists(rviz_config):
        rviz_node = Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            output='screen',
            arguments=['-d', rviz_config],
            parameters=[{'use_sim_time': use_sim_time}],
        )
    else:
        rviz_node = Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            output='screen',
            parameters=[{'use_sim_time': use_sim_time}],
        )

    ld = LaunchDescription()
    # 改动：SLAM延时5秒，RViz延时7秒
    slam_delay = TimerAction(
        period=5.0,
        actions=[cartographer_node, cartographer_occupancy_grid_node]
    )
    rviz_delay = TimerAction(
        period=7.0,
        actions=[rviz_node]
    )
    ld.add_action(slam_delay)
    ld.add_action(rviz_delay)

    return ld