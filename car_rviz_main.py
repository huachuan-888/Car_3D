import sys
import threading
import rclpy
from rclpy.node import Node
from rclpy.action import ActionClient
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from sensor_msgs.msg import Imu
from std_srvs.srv import Trigger
import subprocess
from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                               QPushButton, QSlider, QLabel, QGroupBox, QTextEdit)
from PySide6.QtCore import Qt, QTimer

# ROS2 后台节点
class CarRosNode(Node):
    def __init__(self):
        super().__init__("car_gui_node")
        # 速度发布
        self.cmd_vel_pub = self.create_publisher(Twist, "/cmd_vel", 10)
        # 里程订阅
        self.create_subscription(Odometry, "/odom", self.odom_callback, 10)
        # IMU订阅
        self.create_subscription(Imu, "/imu/data", self.imu_callback, 10)
        # Cartographer 保存地图服务客户端
        self.save_map_client = self.create_client(Trigger, "/cartographer/save_map")

        # 控制变量
        self.linear_x = 0.0
        self.angular_z = 0.0
        # 实时数据缓存
        self.odom_x = 0.0
        self.odom_y = 0.0
        self.roll = 0.0
        self.pitch = 0.0

    # 下发小车速度
    def publish_speed(self):
        msg = Twist()
        msg.linear.x = self.linear_x
        msg.angular.z = self.angular_z
        self.cmd_vel_pub.publish(msg)

    # 里程计回调
    def odom_callback(self, msg):
        self.odom_x = msg.pose.pose.position.x
        self.odom_y = msg.pose.pose.position.y

    # IMU姿态简易解算（俯仰滚转）
    def imu_callback(self, msg):
        self.roll = msg.angular_velocity.x
        self.pitch = msg.angular_velocity.y

    # 保存建图地图
    def save_map(self):
        req = Trigger.Request()
        if self.save_map_client.wait_for_service(timeout_sec=1.0):
            future = self.save_map_client.call_async(req)
            return "地图保存请求已发送"
        else:
            return "保存地图服务未启动"

# Qt主界面窗口
class CarGuiWindow(QMainWindow):
    def __init__(self, ros_node):
        super().__init__()
        self.ros_node = ros_node
        self.setWindowTitle("ROS2 3D建图小车上位机")
        self.resize(550, 700)
        self.init_ui()
        # 界面刷新定时器 100ms
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self.refresh_all_data)
        self.refresh_timer.start(100)

    def init_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # 1. 小车实时状态监控面板
        status_group = QGroupBox("小车实时状态")
        status_layout = QVBoxLayout(status_group)
        self.pos_label = QLabel(f"坐标 X: 0.00 m | Y: 0.00 m")
        self.imu_label = QLabel(f"IMU 滚转: 0.000 | 俯仰: 0.000")
        status_layout.addWidget(self.pos_label)
        status_layout.addWidget(self.imu_label)
        main_layout.addWidget(status_group)

        # 2. 速度滑条控制
        speed_group = QGroupBox("速度调节")
        speed_layout = QVBoxLayout(speed_group)
        # 线速度滑条 -80 ~ 80 对应 -0.8 ~ 0.8 m/s
        self.slider_linear = QSlider(Qt.Horizontal)
        self.slider_linear.setRange(-80, 80)
        self.slider_linear.setValue(0)
        self.slider_linear.valueChanged.connect(self.update_linear)
        speed_layout.addWidget(QLabel("线速度范围：-0.8 ~ 0.8 m/s"))
        speed_layout.addWidget(self.slider_linear)
        # 角速度滑条 -80 ~ 80 对应 -0.8 ~ 0.8 rad/s
        self.slider_angular = QSlider(Qt.Horizontal)
        self.slider_angular.setRange(-80, 80)
        self.slider_angular.setValue(0)
        self.slider_angular.valueChanged.connect(self.update_angular)
        speed_layout.addWidget(QLabel("角速度范围：-0.8 ~ 0.8 rad/s"))
        speed_layout.addWidget(self.slider_angular)
        main_layout.addWidget(speed_group)

        # 3. 方向按键区
        btn_group = QGroupBox("方向快捷控制")
        btn_layout = QVBoxLayout(btn_group)
        # 第一行：前进 默认0.5m/s
        row1 = QHBoxLayout()
        self.btn_forward = QPushButton("前进")
        self.btn_forward.clicked.connect(lambda: self.set_speed(0.5, self.ros_node.angular_z))
        row1.addWidget(self.btn_forward)
        # 第二行：左 停 右
        row2 = QHBoxLayout()
        self.btn_left = QPushButton("左转(+0.1)")
        self.btn_stop = QPushButton("紧急停止")
        self.btn_right = QPushButton("右转(-0.1)")
        self.btn_left.clicked.connect(self.turn_left_add)
        self.btn_right.clicked.connect(self.turn_right_sub)
        self.btn_stop.clicked.connect(lambda: self.set_speed(0.0, 0.0))
        row2.addWidget(self.btn_left)
        row2.addWidget(self.btn_stop)
        row2.addWidget(self.btn_right)
        # 第三行：后退 默认-0.5m/s
        row3 = QHBoxLayout()
        self.btn_back = QPushButton("后退")
        self.btn_back.clicked.connect(lambda: self.set_speed(-0.5, self.ros_node.angular_z))
        row3.addWidget(self.btn_back)

        btn_layout.addLayout(row1)
        btn_layout.addLayout(row2)
        btn_layout.addLayout(row3)
        main_layout.addWidget(btn_group)

        # 4. SLAM建图 + RViz启动按钮
        slam_group = QGroupBox("3D Cartographer 可视化操作")
        slam_layout = QHBoxLayout(slam_group)
        self.btn_save_map = QPushButton("保存地图")
        self.btn_save_map.clicked.connect(self.save_map_action)
        self.btn_rviz = QPushButton("启动RViz可视化")
        self.btn_rviz.clicked.connect(self.start_rviz)
        slam_layout.addWidget(self.btn_save_map)
        slam_layout.addWidget(self.btn_rviz)
        main_layout.addWidget(slam_group)

        # 5. 运行日志输出框
        log_group = QGroupBox("运行日志")
        log_layout = QVBoxLayout(log_group)
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        log_layout.addWidget(self.log_text)
        main_layout.addWidget(log_group)

    # 启动RViz，自动加载你的配置文件
    def start_rviz(self):
        rviz_cmd = [
            "rviz2",
            "-d",
            "/home/huang/car_3D/install/car_description/share/car_description/rviz/ld_depth.rviz"
        ]
        # 后台子进程运行，不阻塞GUI
        subprocess.Popen(rviz_cmd)
        self.log_text.append("已启动RViz可视化窗口")

    # 更新线速度滑条
    def update_linear(self, val):
        self.ros_node.linear_x = val / 100.0

    # 更新角速度滑条
    def update_angular(self, val):
        self.ros_node.angular_z = val / 100.0

    # 固定速度设置（前进/后退保留当前转向）
    def set_speed(self, lin, ang):
        self.ros_node.linear_x = lin
        self.ros_node.angular_z = ang
        self.slider_linear.setValue(int(lin * 100))
        self.slider_angular.setValue(int(ang * 100))
        self.log_text.append(f"已设置：线速度 {lin:.2f} 角速度 {ang:.2f}")

    # 左转累加 +0.1，上限0.8
    def turn_left_add(self):
        new_ang = self.ros_node.angular_z + 0.1
        if new_ang > 0.8:
            new_ang = 0.8
        self.set_speed(self.ros_node.linear_x, new_ang)

    # 右转累加 -0.1，下限-0.8
    def turn_right_sub(self):
        new_ang = self.ros_node.angular_z - 0.1
        if new_ang < -0.8:
            new_ang = -0.8
        self.set_speed(self.ros_node.linear_x, new_ang)

    # 保存地图按钮触发
    def save_map_action(self):
        res = self.ros_node.save_map()
        self.log_text.append(f"地图操作：{res}")

    # 定时刷新界面所有数据
    def refresh_all_data(self):
        # 更新坐标IMU显示
        self.pos_label.setText(f"坐标 X: {self.ros_node.odom_x:.2f} m | Y: {self.ros_node.odom_y:.2f}")
        self.imu_label.setText(f"IMU 滚转: {self.ros_node.roll:.3f} | 俯仰: {self.ros_node.pitch:.3f}")
        # 持续下发速度指令
        self.ros_node.publish_speed()

# ROS2自旋后台线程
def ros_spin_thread(node):
    rclpy.spin(node)

if __name__ == "__main__":
    # 初始化ROS2
    rclpy.init()
    ros_node = CarRosNode()
    # 启动ROS后台线程
    spin_thread = threading.Thread(target=ros_spin_thread, args=(ros_node,), daemon=True)
    spin_thread.start()
    # 启动Qt界面
    app = QApplication(sys.argv)
    window = CarGuiWindow(ros_node)
    window.show()
    app.exec()
    # 退出释放资源
    ros_node.destroy_node()
    rclpy.shutdown()