import os
from launch import LaunchDescription
from launch.substitutions import Command
from launch.actions import ExecuteProcess, RegisterEventHandler, TimerAction
from launch.event_handlers import OnProcessStart
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    package_name = 'car_description'
    urdf_name = "car_robot.urdf.xacro"

    ld = LaunchDescription()
    pkg_share = FindPackageShare(package=package_name).find(package_name) 

    urdf_path = os.path.join(pkg_share, f'urdf/{urdf_name}')
    robot_description = Command(['xacro ', urdf_path])
    rviz_config_path = os.path.join(pkg_share, 'rviz/ld_depth.rviz')
    world_file = os.path.join(pkg_share, 'world/hello2.world')

    # 1. 纯净Gazebo启动，无多余ROS参数
    gazebo_node = ExecuteProcess(
        cmd=[
            'gazebo', 
            '--verbose', 
            world_file,
            '-s', 'libgazebo_ros_factory.so'
        ],
        output='screen'
    )

    # 2. 机器人状态发布，开启仿真时间
    robot_state_publisher_node = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        parameters=[
            {'robot_description': robot_description},
            {'use_sim_time': True}
        ]
    )

    # 3. 生成小车模型
    spawn_entity_node = Node(
        package='gazebo_ros',
        executable='spawn_entity.py',
        arguments=['-entity', 'carbot', '-topic', 'robot_description', '-x', '0.0', '-y', '0.0', '-z', '0.15'],
        output='screen',
        parameters=[{'use_sim_time': True}]
    )

    # RViz可视化节点
    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        arguments=['-d', rviz_config_path],
        output='screen',
        parameters=[{'use_sim_time': True}]
    )

    # 时序：先启动Gazebo
    ld.add_action(gazebo_node)

    # Gazebo启动1秒后启动robot_state_publisher
    delay_after_gazebo = TimerAction(
        period=1.0,
        actions=[robot_state_publisher_node]
    )
    ld.add_action(delay_after_gazebo)

    # robot_state_publisher启动1秒后生成小车
    spawn_after_rsp = RegisterEventHandler(
        OnProcessStart(
            target_action=robot_state_publisher_node,
            on_start=[TimerAction(period=1.0, actions=[spawn_entity_node])]
        )
    )
    ld.add_action(spawn_after_rsp)

    return ld

    # 可选：小车生成完成后延时1s启动RViz（取消注释即可自动启动）
    # rviz_after_spawn = RegisterEventHandler(
    #     OnProcessStart(
    #         target_action=spawn_entity_node,
    #         on_start=[TimerAction(period=1.0, actions=[rviz_node])]
    #     )
    # )
    # ld.add_action(rviz_after_spawn)