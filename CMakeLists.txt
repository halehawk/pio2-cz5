cmake_minimum_required (VERSION 2.8.12)
project (PIO C CXX Fortran)
#cmake_policy(VERSION 3.5.2)

# The project version number.
set(VERSION_MAJOR   3   CACHE STRING "Project major version number.")
set(VERSION_MINOR   5   CACHE STRING "Project minor version number.")
set(VERSION_PATCH   2   CACHE STRING "Project patch version number.")
mark_as_advanced(VERSION_MAJOR VERSION_MINOR VERSION_PATCH)

# The size of the data buffer for write/read_darray().
set(PIO_BUFFER_SIZE 134217728)

#==============================================================================
#  USER-DEFINED OPTIONS (set with "-DOPT=VAL" from command line)
#==============================================================================

#===== Library Options =====
option (PIO_ENABLE_FORTRAN   "Enable the Fortran library builds"            ON)
option (PIO_ENABLE_TIMING    "Enable the use of the GPTL timing library"    ON)
option (PIO_ENABLE_LOGGING   "Enable debug logging (large output possible)" OFF)
option (PIO_ENABLE_DOC       "Enable building PIO documentation"            ON)
option (PIO_ENABLE_COVERAGE  "Enable code coverage"                         OFF)
option (PIO_ENABLE_EXAMPLES  "Enable PIO examples"                          ON)
option (PIO_INTERNAL_DOC     "Enable PIO developer documentation"           OFF)
option (PIO_TEST_BIG_ENDIAN  "Enable test to see if machine is big endian"  ON)
option (PIO_USE_MPIIO        "Enable support for MPI-IO auto detect"        ON)
option (PIO_USE_MPISERIAL    "Enable mpi-serial support (instead of MPI)"   OFF)
option (PIO_USE_MALLOC       "Use native malloc (instead of bget package)"  ON)
option (PIO_USE_PNETCDF_VARD       "Use pnetcdf put_vard "  OFF)
option (WITH_PNETCDF         "Require the use of PnetCDF"                   ON)
option (WITH_Z5              "Require the use of Z5"                        ON)

# Set a variable that appears in the config.h.in file.
if(PIO_USE_PNETCDF_VARD)
  set(USE_VARD 1)
else()
  set(USE_VARD 0)
endif()

# Set a variable that appears in the config.h.in file.
if(PIO_USE_MALLOC)
  set(USE_MALLOC 1)
else()
  set(USE_MALLOC 0)
endif()

# Set a variable that appears in the config.h.in file.
if(PIO_ENABLE_LOGGING)
  set(ENABLE_LOGGING 1)
else()
  set(ENABLE_LOGGING 0)
endif()

if(PIO_USE_MPISERIAL)
  set(USE_MPI_SERIAL 1)
else()
  set(USE_MPI_SERIAL 0)
endif()

#==============================================================================
#  PREPEND TO CMAKE MODULE PATH
#==============================================================================

#===== Local modules =====
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

#===== External modules =====
if (NOT DEFINED USER_CMAKE_MODULE_PATH)
  message (STATUS "Importing CMake_Fortran_utils")
  execute_process(
    COMMAND git clone https://github.com/CESM-Development/CMake_Fortran_utils
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    OUTPUT_QUIET
    ERROR_QUIET)
  find_path (USER_CMAKE_MODULE_PATH
    NAMES mpiexec.cmake
    HINTS ${CMAKE_BINARY_DIR}/CMake_Fortran_utils)
  if (USER_CMAKE_MODULE_PATH)
    message (STATUS "Importing CMake_Fortran_utils - success")
  else ()
    message (FATAL_ERROR "Failed to import CMake_Fortran_utils")
  endif ()
endif ()
set (USER_CMAKE_MODULE_PATH ${USER_CMAKE_MODULE_PATH}
  CACHE STRING "Location of the CMake_Fortran_utils")
list (APPEND CMAKE_MODULE_PATH ${USER_CMAKE_MODULE_PATH})

INCLUDE (CheckTypeSize)

#===== MPI =====
if (PIO_USE_MPISERIAL)
  find_package (MPISERIAL COMPONENTS C REQUIRED)
  if (MPISERIAL_C_FOUND)
    set (CMAKE_REQUIRED_INCLUDES ${MPISERIAL_C_INCLUDE_DIRS})
  endif ()
else ()
  find_package (MPI REQUIRED)
  set (CMAKE_REQUIRED_INCLUDES ${MPI_INCLUDE_PATH})
endif ()

SET(CMAKE_EXTRA_INCLUDE_FILES "mpi.h")
check_type_size("MPI_Offset" SIZEOF_MPI_OFFSET)
SET(CMAKE_EXTRA_INCLUDE_FILES)

#===== Library Variables =====
set (PIO_FILESYSTEM_HINTS IGNORE CACHE STRING "Filesystem hints (lustre or gpfs)")

#===== Testing Options =====
option (PIO_ENABLE_TESTS  "Enable the testing builds"                           ON)
option (PIO_VALGRIND_CHECK  "Enable memory leak check using valgrind"           OFF)

#==============================================================================
#  Z5 BACKEND
#==============================================================================

# Z5
if (DEFINED Z5_DIR)
  message("Z5_DIR: " ${Z5_DIR})
  set(Z5_DIR CACHE PATH "z5 location")
  include_directories(${Z5_DIR})
  #boost
  find_package(Boost REQUIRED COMPONENTS system filesystem)
  message("Boost_FILESYSTEM_LIBRARY:" ${Boost_FILESYSTEM_LIBRARY})
  message("Boost_SYSTEM_LIBRARY:" ${Boost_SYSTEM_LIBRARY})
  set(BOOST_LIBRARIES
          ${Boost_FILESYSTEM_LIBRARY}
          ${Boost_SYSTEM_LIBRARY})
  #zlib
  option(WITH_ZLIB ON)
  if(WITH_ZLIB)
    find_package(ZLIB REQUIRED)
    set(ZLIB_ROOT CACHE PATH "zlib location")
    include_directories(${ZLIB_INCLUDE_DIRS})
    message("ZLIB_INCLUDE_DIRS: " ${ZLIB_INCLUDE_DIRS})
    add_definitions(-DWITH_ZLIB)
    SET(COMPRESSION_LIBRARIES "${COMPRESSION_LIBRARIES};${ZLIB_LIBRARIES}")
  endif()
  message("BLOSC_ROOT:" ${BLOSC_SEARCH_HEADER_PATHS})
  option(WITH_BLOSC ON)
  if(WITH_BLOSC)
    find_package(BLOSC REQUIRED)
    #set(BLOSC_SEARCH_HEADER_PATHS CACHE PATH "blosc header location")
    #set(BLOSC_SEARCH_LIB_PATH CACHE PATH "blosc lib location")
    include_directories(${BLOSC_INCLUDE_DIR})
    message("BLOSC_INCLUDE_DIRS: " ${BLOSC_INCLUDE_DIR})
    message("BLOSC_LIBRARY: " ${BLOSC_LIBRARIES})
    add_definitions(-DWITH_BLOSC)
    SET(COMPRESSION_LIBRARIES "${COMPRESSION_LIBRARIES};${BLOSC_LIBRARIES}")
  endif()
  #lz4
  option(WITH_LZ4 ON)
  if(WITH_LZ4)
    find_package(LZ4 REQUIRED)
    set(LZ4_ROOT CACHE PATH "lz4 location")
    include_directories(${LZ4_INCLUDE_DIR})
    add_definitions(-DWITH_LZ4)
    SET(COMPRESSION_LIBRARIES "${COMPRESSION_LIBRARIES};${LZ4_LIBRARY}")
  endif()
  #CXX 11
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -cxxlib=/glade/u/home/weile/miniconda3/envs/z5-py36/ -pthread /glade/u/home/weile/miniconda3/envs/z5-py36/lib/libstdc++.so")
  message(${CMAKE_CXX_FLAGS})
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  #MARRAY
  option(WITH_MARRAY ON)
  if(WITH_MARRAY)
    set(MARRAY_INCLUDE_DIR ${CMAKE_PREFIX_PATH} CACHE PATH "marray location")
    add_definitions(-DWITH_MARRAY)
    include_directories(${MARRAY_INCLUDE_DIR})
    message("MARRAY_INCLUDE_DIR:" ${MARRAY_INCLUDE_DIR})
  endif()
  set(CMAKE_PREFIX_PATH CACHE PATH "CMAKE_PREFIX_PATH path")
endif ()

#==============================================================================
#  BACKWARDS COMPATIBILITY
#==============================================================================

# Old NETCDF_DIR variable --> NetCDF_PATH
if (DEFINED NETCDF_DIR)
  set (NetCDF_PATH ${NETCDF_DIR}
    CACHE STRING "Location of the NetCDF library installation")
endif ()

# Old PNETCDF_DIR variable --> PnetCDF_PATH
if (DEFINED PNETCDF_DIR)
  set (PnetCDF_PATH ${PNETCDF_DIR}
    CACHE STRING "Location of the PnetCDF library installation")
endif ()

#==============================================================================
#  HELPFUL GLOBAL VARIABLES
#==============================================================================

# System Name
string (TOUPPER "${CMAKE_SYSTEM_NAME}" CMAKE_SYSTEM_NAME_CAPS)
set (CMAKE_SYSTEM_DIRECTIVE "${CMAKE_SYSTEM_NAME_CAPS}"
  CACHE STRING "System name preprocessor directive")

# C Compiler Name
string (TOUPPER "${CMAKE_C_COMPILER_ID}" CMAKE_C_COMPILER_NAME)
if (CMAKE_C_COMPILER_NAME STREQUAL "XL")
  set (CMAKE_C_COMPILER_NAME "IBM")
endif ()
set (CMAKE_C_COMPILER_DIRECTIVE "CPR${CMAKE_C_COMPILER_NAME}"
  CACHE STRING "C compiler name preprocessor directive")

# Fortran Compiler Name
string (TOUPPER "${CMAKE_Fortran_COMPILER_ID}" CMAKE_Fortran_COMPILER_NAME)
if (CMAKE_Fortran_COMPILER_NAME STREQUAL "XL")
  set (CMAKE_Fortran_COMPILER_NAME "IBM")
endif ()
set (CMAKE_Fortran_COMPILER_DIRECTIVE "CPR${CMAKE_Fortran_COMPILER_NAME}"
  CACHE STRING "Fortran compiler name preprocessor directive")

# configure a header file to pass some of the CMake settings
# to the source code
configure_file (
  "${PROJECT_SOURCE_DIR}/cmake_config.h.in"
  "${PROJECT_BINARY_DIR}/config.h"
  )

#==============================================================================
#  SET CODE COVERAGE COMPILER FLAGS
#==============================================================================

# Only support GNU compilers at this time
if (PIO_ENABLE_COVERAGE)
  if (CMAKE_C_COMPILER_NAME STREQUAL "GNU")
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fprofile-arcs -ftest-coverage")
  else ()
    message (WARNING "The C compiler is non-GNU: coverage of C code could NOT be enabled")
  endif ()
  if (CMAKE_Fortran_COMPILER_NAME STREQUAL "GNU")
    set (CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fprofile-arcs -ftest-coverage")
  else ()
    message (WARNING "The Fortran compiler is non-GNU: coverage of Fortran code could NOT be enabled")
  endif ()
endif ()

#==============================================================================
#  INCLUDE SOURCE DIRECTORIES
#==============================================================================

# Libraries
add_subdirectory (src)

#==============================================================================
#  TESTING TARGET
#==============================================================================

# Custom "piotests" target (builds the test executables)
add_custom_target (tests)

# Custom "check" target that depends upon "tests"
add_custom_target (check COMMAND ${CMAKE_CTEST_COMMAND})
add_dependencies (check tests)

# Tests
if (PIO_ENABLE_TESTS)
  enable_testing()
  include (CTest)
  add_subdirectory (tests)
  if (PIO_ENABLE_EXAMPLES)
    add_subdirectory (examples)
  endif ()
endif ()

# Documentation
if (PIO_ENABLE_DOC)
  add_subdirectory (doc)
endif ()
