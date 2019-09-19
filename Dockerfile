FROM ubuntu:bionic

RUN apt-get update && apt-get install -q -y gnupg

# ROS1 base dependencies
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu bionic main" > /etc/apt/sources.list.d/ros-latest.list' && \
	apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 && \
	apt-get update

RUN apt-get update && apt-get install -y -q apt-utils && DEBIAN_FRONTEND=noninteractive apt-get install -q -y python-rosdep python-rosinstall-generator python-wstool python-rosinstall build-essential
RUN rosdep init && rosdep update
RUN mkdir /ros_catkin_ws
WORKDIR /ros_catkin_ws
RUN rosinstall_generator ros_comm --rosdistro melodic --deps --tar > melodic-ros_comm.rosinstall && \
	wstool init -j8 src melodic-ros_comm.rosinstall
RUN DEBIAN_FRONTEND=noninteractive rosdep install --from-paths src --ignore-src --rosdistro melodic -y
RUN ./src/catkin/bin/catkin_make_isolated --install -DCMAKE_BUILD_TYPE=Release

# FROM ubuntu:bionic

# COPY --from=0 /ros_catkin_ws /ros_catkin_ws

WORKDIR /

# ROS2 installation
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y locales

RUN locale-gen en_US en_US.UTF-8
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
RUN export LANG=en_US.UTF-8

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg2 lsb-release
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN sh -c 'echo "deb http://packages.ros.org/ros2/ubuntu `lsb_release -cs` main" > /etc/apt/sources.list.d/ros2-latest.list'

ENV CHOOSE_ROS_DISTRO=dashing
RUN apt-get update

# ROS2 dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
  	build-essential \
  	cmake \
  	git \
  	python3-colcon-common-extensions \
  	python3-lark-parser \
  	python3-pip \
  	python-rosdep \
  	python3-vcstool \
  	wget

RUN python3 -m pip install -U \
  	argcomplete \
  	flake8 \
  	flake8-blind-except \
  	flake8-builtins \
  	flake8-class-newline \
  	flake8-comprehensions \
  	flake8-deprecated \
  	flake8-docstrings \
  	flake8-import-order \
  	flake8-quotes \
  	pytest-repeat \
  	pytest-rerunfailures \
  	pytest \
  	pytest-cov \
  	pytest-runner \
  	setuptools

# install Fast-RTPS dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
  	libasio-dev \
  	libtinyxml2-dev

RUN mkdir -p /ros2_ws/src
WORKDIR /ros2_ws/
RUN wget https://raw.githubusercontent.com/conroy-cheers/ros2/dashing/ros2-lite.repos
RUN vcs import src < ros2-lite.repos

RUN rosdep update
RUN rosdep install --from-paths src --ignore-src --rosdistro dashing -y --skip-keys "console_bridge fastcdr fastrtps libopensplice67 libopensplice69 rti-connext-dds-5.3.1 urdfdom_headers rviz_ogre_vendor rviz_default_plugins"

# build ros2 except for ros1_bridge
RUN colcon build --merge-install --packages-skip ros1_bridge --cmake-args -DDISABLE_SANITIZERS=ON

# delete wasteful things
RUN rm -rf build/ src/

# -------------------------------------------------------------------

RUN apt-get install -y python-catkin-tools

RUN apt-get clean

# set up ros1 overlay
RUN mkdir -p /ros1_overlay_ws/
WORKDIR /ros1_overlay_ws/
RUN /bin/bash -c "catkin init && \
	wstool init src"

# set up ros2 overlay
RUN mkdir -p /ros2_overlay_ws/src
WORKDIR /ros2_overlay_ws/
