cmake_minimum_required(VERSION 3.22)

# iOS target: configure with
#   cmake -S . -B build -G Xcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos
set(CMAKE_SYSTEM_NAME iOS CACHE STRING "" FORCE)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "" FORCE)
if(NOT DEFINED SA_BUNDLE_ID OR SA_BUNDLE_ID STREQUAL "")
    set(SA_BUNDLE_ID "com.nasser.shadowarchitect")
endif()
set(CMAKE_XCODE_GENERATE_SCHEME ON)
set(CMAKE_XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
set(CMAKE_XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${SA_BUNDLE_ID}")

project(ShadowArchitect LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(ShadowArchitect MACOSX_BUNDLE
    GameCore.cpp
    Audio.cpp
    ios/main.mm
    ios/AppDelegate.mm
    ios/GameViewController.mm
    ios/GameView.mm
)

target_include_directories(ShadowArchitect PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

set_source_files_properties(ios/LaunchScreen.storyboard ios/AppIcon.png PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources)
target_sources(ShadowArchitect PRIVATE ios/LaunchScreen.storyboard ios/AppIcon.png)

set_target_properties(ShadowArchitect PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${SA_BUNDLE_ID}"
    MACOSX_BUNDLE_BUNDLE_NAME "Shadow Architect"
    MACOSX_BUNDLE_DISPLAY_NAME "مهندس الظلال"
    MACOSX_BUNDLE_ICON_FILE "AppIcon.png"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${SA_BUNDLE_ID}"
    XCODE_ATTRIBUTE_LAUNCH_SCREEN "LaunchScreen"
    XCODE_GENERATE_SCHEME ON
)

find_library(UIKIT UIKit REQUIRED)
find_library(AVFOUNDATION AVFoundation REQUIRED)
find_library(QUARTZCORE QuartzCore REQUIRED)
target_link_libraries(ShadowArchitect PRIVATE ${UIKIT} ${AVFOUNDATION} ${QUARTZCORE})

if(MSVC)
    target_compile_options(ShadowArchitect PRIVATE /utf-8)
else()
    set_source_files_properties(
        ios/main.mm ios/AppDelegate.mm ios/GameViewController.mm ios/GameView.mm
        PROPERTIES COMPILE_FLAGS "-fobjc-arc")
endif()
