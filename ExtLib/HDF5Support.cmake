
# -------------------------------------------------------------
# This function adds the necessary cmake code to find the HDF5
# shared libraries and setup custom copy commands and/or install
# rules for Linux and Windows to use
function(AddHDF5CopyInstallRules)
  set(options )
  set(oneValueArgs LIBNAME LIBVAR)
  set(multiValueArgs TYPES)
  cmake_parse_arguments(Z "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )
  set(INTER_DIR ".")

  # message(STATUS "Z_LIBNAME: ${Z_LIBNAME}")
  # message(STATUS "Z_LIBVAR: ${Z_LIBVAR}")
  # message(STATUS "Z_TYPES: ${Z_TYPES}")

  set(Z_INSTALL_DIR "lib")
  if(WIN32)
    set(Z_INSTALL_DIR ".")
  endif()

  FOREACH(BTYPE ${Z_TYPES} )
    #message(STATUS "BTYPE: ${BTYPE}")
    STRING(TOUPPER ${BTYPE} TYPE)
    if(MSVC_IDE)
      set(INTER_DIR "${BTYPE}")
    endif()

    # Get the Actual Library Path and create Install and copy rules
    GET_TARGET_PROPERTY(LibPath ${Z_LIBNAME} IMPORTED_LOCATION_${TYPE})
    # message(STATUS "LibPath: ${LibPath}")
    if(NOT "${LibPath}" STREQUAL "LibPath-NOTFOUND")
      # message(STATUS "Creating Install Rule for ${LibPath}")
      if(NOT TARGET ZZ_${Z_LIBVAR}_DLL_${TYPE}-Copy)
        ADD_CUSTOM_TARGET(ZZ_${Z_LIBVAR}_DLL_${TYPE}-Copy ALL
                            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${LibPath}
                            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${INTER_DIR}/
                            # COMMENT "  Copy: ${LibPath} To: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${INTER_DIR}/"
                            )
        set_target_properties(ZZ_${Z_LIBVAR}_DLL_${TYPE}-Copy PROPERTIES FOLDER ZZ_COPY_FILES/${BTYPE}/HDF5)
        install(FILES ${LibPath} DESTINATION "${Z_INSTALL_DIR}" CONFIGURATIONS ${BTYPE} COMPONENT Applications)
      endif()
    endif()

    # Now get the path that the library is in
    GET_FILENAME_COMPONENT(${Z_LIBVAR}_DIR ${LibPath} PATH)
    # message(STATUS "${Z_LIBVAR}_DIR: ${${Z_LIBVAR}_DIR}")

    # Now piece together a complete path for the symlink that Linux Needs to have
    if(WIN32)
      GET_TARGET_PROPERTY(${Z_LIBVAR}_${TYPE} ${Z_LIBNAME} IMPORTED_IMPLIB_${TYPE})
    else()
      GET_TARGET_PROPERTY(${Z_LIBVAR}_${TYPE} ${Z_LIBNAME} IMPORTED_SONAME_${TYPE})
    endif()

    # message(STATUS "${Z_LIBVAR}_${TYPE}: ${${Z_LIBVAR}_${TYPE}}")
    if(NOT "${${Z_LIBVAR}_${TYPE}}" STREQUAL "${Z_LIBVAR}_${TYPE}-NOTFOUND" AND NOT WIN32)
      set(SYMLINK_PATH "${${Z_LIBVAR}_DIR}/${${Z_LIBVAR}_${TYPE}}")
      # message(STATUS "Creating Install Rule for ${SYMLINK_PATH}")
      if(NOT TARGET ZZ_${Z_LIBVAR}_SYMLINK_${TYPE}-Copy)
        ADD_CUSTOM_TARGET(ZZ_${Z_LIBVAR}_SYMLINK_${TYPE}-Copy ALL
                            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${SYMLINK_PATH}
                            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${INTER_DIR}/
                            # COMMENT "  Copy: ${SYMLINK_PATH} To: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${INTER_DIR}/"
                            )
        set_target_properties(ZZ_${Z_LIBVAR}_SYMLINK_${TYPE}-Copy PROPERTIES FOLDER ZZ_COPY_FILES/${BTYPE}/HDF5)
        install(FILES ${SYMLINK_PATH} DESTINATION "${Z_INSTALL_DIR}" CONFIGURATIONS ${BTYPE} COMPONENT Applications)
      endif()
    endif()

  endforeach()
endfunction()


#------------------------------------------------------------------------------
# Find HDF5 Headers/Libraries
# HDF5 now comes with everything that is needed for CMake to load
# up the targets (Exported) that it needs. We just need to find where HDF5 is installed.
#------------------------------------------------------------------------------
if("${HDF5_INSTALL}" STREQUAL "")
    set(HDF5_INSTALL  $ENV{HDF5_INSTALL})
endif()

if( "${HDF5_INSTALL}" STREQUAL "")
  message(FATAL_ERROR "The HDF5_INSTALL variable was not set. In order to find HDF5 you need to either\
                      pass in the -DHDF5_INSTALL=.... or set the HDF5_INSTALL environment variable.")
endif()

# We used to set the CMAKE_MODULE_PATH but HDF5 is changing where they put the 
# cmake files from HDF5 1.8.14 to 1.8.15 so we are going to ask the user to set 
# the CMAKE_MODULE_PATH in their DREAM3D_SDK.cmake file instead.
#if(WIN32)
    #set(ENV{HDF5_ROOT_DIR_HINT} "${HDF5_INSTALL}/cmake/hdf5")
    #set(ENV{HDF5_ROOT} "${HDF5_INSTALL}")
    #set(CMAKE_MODULE_PATH ${HDF5_INSTALL}/cmake/hdf5 ${CMAKE_MODULE_PATH})
#else()
    #set(ENV{HDF5_ROOT_DIR_HINT} "${HDF5_INSTALL}/share/cmake")
    #set(ENV{HDF5_ROOT} "${HDF5_INSTALL}")
    #set(CMAKE_MODULE_PATH ${HDF5_INSTALL}/share/cmake/hdf5 ${CMAKE_MODULE_PATH})
#endif()

find_package(HDF5 NAMES hdf5)
if(HDF5_FOUND)


  # Add the library directory to the file that has all the search directories stored in it.

  include_directories(${HDF5_INCLUDE_DIRS}) #HDF5 1.8.15 and below
  include_directories(${HDF5_INCLUDE_DIR}) #HDF5 1.8.16 and above

  get_property(HDF5_STATUS_PRINTED GLOBAL PROPERTY HDF5_STATUS_PRINTED)
  if(NOT HDF5_STATUS_PRINTED)
    message(STATUS "HDF5 Location: ${HDF5_INSTALL}")
    message(STATUS "HDF5 Version: ${HDF5_VERSION_STRING}")
    set_property(GLOBAL PROPERTY HDF5_STATUS_PRINTED TRUE)

    GET_FILENAME_COMPONENT (HDF5_LIBRARY_DIRS "${HDF5_INCLUDE_DIR}" PATH)
    set(HDF5_LIBRARY_DIRS ${HDF5_LIBRARY_DIRS}/lib)
    file(APPEND ${CMP_PLUGIN_SEARCHDIR_FILE} "${HDF5_LIBRARY_DIRS};")
  
  endif()

  if(MSVC_IDE)
    set(BUILD_TYPES Debug Release)
  else()
    set(BUILD_TYPES "${CMAKE_BUILD_TYPE}")
    if("${BUILD_TYPES}" STREQUAL "")
        set(BUILD_TYPES "Debug")
    endif()
  endif()

  if(TARGET hdf5) 
    set(HDF5_C_TARGET_NAME hdf5)
  elseif(TARGET hdf5-shared)
    set(HDF5_C_TARGET_NAME hdf5-shared)
  else()
    message(FATAL_ERROR "Neither target hdf5 nor target hdf5-shared was found. Do you have HDF5 1.8.15 or HDF5 1.8.16 installed.")
  endif()

  if(TARGET hdf5_cpp)
    set(HDF5_CXX_TARGET_NAME hdf5_cpp)
  elseif(TARGET hdf5_cpp-shared)
    set(HDF5_CXX_TARGET_NAME hdf5_cpp-shared)
  else()
    message(FATAL_ERROR "Neither target hdf5_cpp nor target hdf5_cpp-shared was found. Do you have HDF5 1.8.15 or HDF5 1.8.16 installed.")
  endif()

  if(NOT APPLE)
    AddHDF5CopyInstallRules(LIBVAR HDF5_LIB
                        LIBNAME ${HDF5_C_TARGET_NAME}
                        TYPES ${BUILD_TYPES})
    AddHDF5CopyInstallRules(LIBVAR HDF5_CPP_LIB
                        LIBNAME ${HDF5_CXX_TARGET_NAME}
                        TYPES ${BUILD_TYPES})
  endif()

  # The next CMake variable is needed for Linux to properly generate a shell script
  # that will properly install the HDF5 files.
  if(NOT APPLE AND NOT WIN32)
    STRING(TOUPPER ${CMAKE_BUILD_TYPE} TYPE)
    get_target_property(HDF5_C_LIB_PATH ${HDF5_C_TARGET_NAME} IMPORTED_LOCATION_${TYPE})
    get_target_property(HDF5_CXX_LIB_PATH ${HDF5_CXX_TARGET_NAME} IMPORTED_LOCATION_${TYPE})
    set(HDF5_COMPONENTS ${HDF5_C_LIB_PATH} ${HDF5_CXX_LIB_PATH})
  endif()

ELSE(HDF5_FOUND)
    MESSAGE(FATAL_ERROR "Cannot build without HDF5.  Please set HDF5_INSTALL environment variable to point to your HDF5 installation.")
ENDif(HDF5_FOUND)

