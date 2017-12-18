if (NOT BUILD_PYTHON)
	return()
endif()

if(NOT TARGET ortools::ortools)
	message(FATAL_ERROR "Python: missing ortools TARGET")
endif()

# Will need swig
find_package(SWIG REQUIRED)
include(UseSWIG)

# Generate Protobuf py sources
set(PROTO_PYS)
file(GLOB_RECURSE proto_py_files RELATIVE ${PROJECT_SOURCE_DIR}
	"ortools/constraint_solver/*.proto"
	"ortools/linear_solver/*.proto")
list(REMOVE_ITEM proto_py_files "ortools/constraint_solver/demon_profiler.proto")
foreach(PROTO_FILE ${proto_py_files})
	message(STATUS "protoc: ${PROTO_FILE}")
	get_filename_component(PROTO_DIR ${PROTO_FILE} DIRECTORY)
	get_filename_component(PROTO_NAME ${PROTO_FILE} NAME_WE)
	set(PROTO_PY ${PROJECT_BINARY_DIR}/${PROTO_DIR}/${PROTO_NAME}_pb2.py)
	message(STATUS "protoc py: ${PROTO_PY}")
	add_custom_command(
		OUTPUT ${PROTO_PY}
		COMMAND protobuf::protoc
		"--proto_path=${PROJECT_SOURCE_DIR}"
		"--python_out=${PROJECT_BINARY_DIR}"
		${PROTO_FILE}
		DEPENDS ${PROTO_FILE} protobuf::protoc
		COMMENT "Running C++ protocol buffer compiler on ${PROTO_FILE}"
		VERBATIM)
	list(APPEND PROTO_PYS ${PROTO_PY})
endforeach()
add_custom_target(Py${PROJECT_NAME}_proto DEPENDS ${PROTO_PYS} ortools::ortools)

# Build Python wrappers
# Specify supported python version
set(Python_ADDITIONAL_VERSIONS "3.6;3.5;2.7"
	CACHE STRING "available python version")
find_package(PythonInterp REQUIRED)
find_package(PythonLibs REQUIRED)

if(${PYTHON_VERSION_STRING} VERSION_GREATER 3)
	set(CMAKE_SWIG_FLAGS "-py3;-DPY3")
endif()

# CMake will remove all '-D' prefix (i.e. -DUSE_FOO become USE_FOO)
#get_target_property(FLAGS ortools::ortools COMPILE_DEFINITIONS)
set(FLAGS -DUSE_BOP -DUSE_GLOP -DUSE_CBC -DUSE_CLP)
list(APPEND CMAKE_SWIG_FLAGS ${FLAGS} "-I${PROJECT_SOURCE_DIR}")

foreach(SUBPROJECT constraint_solver linear_solver sat graph algorithms data)
	add_subdirectory(ortools/${SUBPROJECT}/python)
endforeach()

configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/constraint_solver/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/linear_solver/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/sat/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/sat/python COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/graph/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/algorithms/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/__init__.py ${PROJECT_BINARY_DIR}/ortools/data/ COPYONLY)

configure_file(${PROJECT_SOURCE_DIR}/ortools/linear_solver/linear_solver_natural_api.py
	${PROJECT_BINARY_DIR}/ortools/linear_solver/ COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/sat/python/cp_model.py
	${PROJECT_BINARY_DIR}/ortools/sat/python COPYONLY)
configure_file(${PROJECT_SOURCE_DIR}/ortools/sat/python/visualization.py
	${PROJECT_BINARY_DIR}/ortools/sat/python COPYONLY)

# To use a cmake generator expression (aka $<>), it must be processed at build time
# i.e. inside a add_custom_command()
add_custom_command(OUTPUT setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "from setuptools import dist, find_packages, setup" > setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "class BinaryDistribution(dist.Distribution):" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  def is_pure(self):" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "    return False" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  def has_ext_modules(self):" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "    return True" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "setup(" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  name='ortools'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  license='Apache 2.0'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  version='${PROJECT_VERSION}'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  author='Google Inc'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  author_email = 'lperron@google.com'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  description = 'Google OR-Tools python libraries and modules'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  long_description = 'read(README.txt)'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  keywords = ('operations research' +" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  ', constraint programming' +" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  ', linear programming' +" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  ', flow algoritms' +" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  ', python')," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  url = 'https://developers.google.com/optimization/'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  download_url = 'https://github.com/google/or-tools/releases'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  distclass=BinaryDistribution," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  packages=find_packages()," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  package_data={" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'ortools':['$<TARGET_FILE:ortools>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'ortools.constraint_solver':['$<TARGET_FILE:_pywrapcp>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "	'ortools.linear_solver':['$<TARGET_FILE:_pywraplp>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "	'ortools.sat':['$<TARGET_FILE:_pywrapsat>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "	'ortools.graph':['$<TARGET_FILE:_pywrapgraph>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "	'ortools.algorithms':['$<TARGET_FILE:_pywrapknapsack_solver>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "	'ortools.data':['$<TARGET_FILE:_pywraprcpsp>']," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  }," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  include_package_data=True," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  install_requires=[" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'protobuf >= ${protobuf_VERSION}'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'six >= 1.10'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  ]," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  classifiers=[" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Development Status :: 5 - Production/Stable'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Intended Audience :: Developers'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'License :: OSI Approved :: Apache Software License'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Operating System :: POSIX :: Linux'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Operating System :: MacOS :: MacOS X'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Operating System :: Microsoft :: Windows'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Programming Language :: Python :: 2'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Programming Language :: Python :: 2.7'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Programming Language :: Python :: 3'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Programming Language :: Python :: 3.5'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Programming Language :: Python :: 3.6'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Topic :: Office/Business :: Scheduling'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Topic :: Scientific/Engineering'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Topic :: Scientific/Engineering :: Mathematics'," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  'Topic :: Software Development :: Libraries :: Python Modules'" >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo "  ]," >> setup.py
	COMMAND ${CMAKE_COMMAND} -E echo ")" >> setup.py
	VERBATIM)

# Main Target
add_custom_target(bdist
	DEPENDS setup.py Py${PROJECT_NAME}_proto
	COMMAND ${PYTHON_EXECUTABLE} setup.py bdist
	)

