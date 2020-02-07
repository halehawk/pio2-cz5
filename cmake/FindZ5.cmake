# - Try to find Z5
#
# This can be controlled by setting the PAPI_DIR (or, equivalently, the 
# PAPI environment variable).
#
# Once done, this will define:
#
#   PAPI_FOUND        (BOOL) - system has PAPI
#   PAPI_IS_SHARED    (BOOL) - whether library is shared/dynamic
#   PAPI_INCLUDE_DIR  (PATH) - Location of the C header file
#   PAPI_INCLUDE_DIRS (LIST) - the PAPI include directories
#   PAPI_LIBRARY      (FILE) - Path to the C library file
#   PAPI_LIBRARIES    (LIST) - link these to use PAPI
#
include (LibFind)

# Define PAPI package
define_package_component (Z5WRAPPER
                          INCLUDE_NAMES z5rwapper.h
                          LIBRARY_NAMES z5wrapper)

# SEARCH FOR PACKAGE
if (NOT Z5WRAPPER_FOUND)

    # Search for the package
    find_package_component(Z5WRAPPER)

endif ()
