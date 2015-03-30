# Copyright (c) 2012-2014 Stefan Eilemann <eile@eyescale.ch>

# Configures a Doxyfile and provides doxygen and doxycopy targets. Relies on
# TargetHooks installed by Common and must be included after all targets!
#
# Input Variables
# * DOXYGEN_EXTRA_INPUT additional parsed input files, appended to INPUT in
#   Doxyfile
# * DOXYGEN_EXTRA_EXCLUDE additional excluded input files, appended to EXCLUDE
#   in Doxyfile
# * DOXYGEN_EXTRA_FILES additional files to be copied to documentation,
#   appended to HTML_EXTRA_FILES in Doxyfile
# * DOXYGEN_PROJECT_NAME the name to use in the documentation title. Defaults
#   to PROJECT_NAME if not provided.
# * DOXYGEN_MAINPAGE_MD markdown file to use as main page. See
#   USE_MDFILE_AS_MAINPAGE doxygen documentation for details.
# * DOXYGIT_MAX_VERSIONS number of versions to keep in directory
#
# Optional project information
# Output to a metadata file for html index page generation by Jekyll
# * ${UPPER_PROJECT_NAME}_DESCRIPTION A short description of the project
# * ${UPPER_PROJECT_NAME}_ISSUES_URL A link pointing to the ticket tracker
# * ${UPPER_PROJECT_NAME}_PACKAGE_URL A link pointing to the package repository
# * ${UPPER_PROJECT_NAME}_MATURITY EP, RD or RS
#
# IO Variables (set if not set as input)
# * GIT_DOCUMENTATION_REPO or GIT_ORIGIN_org is used
# * DOXYGEN_CONFIG_FILE or one is auto-configured
# * COMMON_ORGANIZATION_NAME (from GithubInfo. Defaults to: Unknown)
# * COMMON_PROJECT_DOMAIN a reverse DNS name. (Defaults to: org.doxygen)
#
# Generated targets
# * doxygen runs doxygen after compiling and installing the project
# * doxycopy runs doxygen and copies the documentation to the documention git
#   repository, which is assumed to be located at:
#   PROJECT_SOURCE_DIR/../GIT_DOCUMENTATION_REPO or
#   PROJECT_SOURCE_DIR/../GIT_ORIGIN_org
#   When using Buildyard, this repository is automatically cloned if it was
#   correctly declared as a project dependency.
#   When using subprojects, it is the responsiblity of the user to clone
#   the documentation repository in the project's parent folder.

find_package(Doxygen)
if(NOT DOXYGEN_FOUND)
  return()
endif()

get_property(INSTALL_DEPENDS GLOBAL PROPERTY ${PROJECT_NAME}_ALL_DEP_TARGETS)
if(NOT INSTALL_DEPENDS)
  message(FATAL_ERROR "No targets in CMake project, Common.cmake not used?")
endif()

if(NOT GIT_DOCUMENTATION_REPO)
  include(GithubInfo)
  set(GIT_DOCUMENTATION_REPO ${GIT_ORIGIN_org})
endif()

if(NOT PROJECT_PACKAGE_NAME)
  if(NOT COMMON_PROJECT_DOMAIN)
    set(COMMON_PROJECT_DOMAIN org.doxygen)
    message(STATUS "Set COMMON_PROJECT_DOMAIN to ${COMMON_PROJECT_DOMAIN}")
  endif()
  set(PROJECT_PACKAGE_NAME ${COMMON_PROJECT_DOMAIN}.${LOWER_PROJECT_NAME})
  message(STATUS "Using ${PROJECT_PACKAGE_NAME} for documentation")
endif()

if(NOT DOXYGEN_PROJECT_NAME)
  set(DOXYGEN_PROJECT_NAME ${PROJECT_NAME})
endif()

if(NOT COMMON_ORGANIZATION_NAME)
  set(COMMON_ORGANIZATION_NAME Unknown)
  message(STATUS "Using ${COMMON_ORGANIZATION_NAME} as organization")
endif()

if(NOT DOXYGEN_CONFIG_FILE)
  # Assuming there exists a Doxyfile and that needs configuring
  configure_file(${CMAKE_CURRENT_LIST_DIR}/Doxyfile
    ${PROJECT_BINARY_DIR}/doc/Doxyfile @ONLY)
  set(DOXYGEN_CONFIG_FILE ${PROJECT_BINARY_DIR}/doc/Doxyfile)
endif()

add_custom_target(${PROJECT_NAME}_doxygen_install
  ${CMAKE_COMMAND} -P ${PROJECT_BINARY_DIR}/cmake_install.cmake
  DEPENDS ${INSTALL_DEPENDS})

if(NOT TARGET doxygen_install)
  add_custom_target(doxygen_install)
endif()
add_dependencies(doxygen_install ${PROJECT_NAME}_doxygen_install)

add_custom_target(${PROJECT_NAME}_doxygen_html
  ${DOXYGEN_EXECUTABLE} ${DOXYGEN_CONFIG_FILE}
  WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/doc
  COMMENT "Generating API documentation using doxygen" VERBATIM
  DEPENDS ${PROJECT_NAME}_doxygen_install project_info_${PROJECT_NAME})

if(NOT TARGET doxygen_html)
  add_custom_target(doxygen_html)
endif()
add_dependencies(doxygen_html ${PROJECT_NAME}_doxygen_html)

if(COVERAGE)
  # CoverageReport generated in this case
  add_custom_target(${PROJECT_NAME}_doxygen DEPENDS ${PROJECT_NAME}_doxygen_html tests)
else()
  add_custom_target(${PROJECT_NAME}_doxygen DEPENDS ${PROJECT_NAME}_doxygen_html)
endif()

if(NOT TARGET doxygen)
  add_custom_target(doxygen)
endif()
add_dependencies(doxygen ${PROJECT_NAME}_doxygen)

make_directory(${PROJECT_BINARY_DIR}/doc/html)
install(DIRECTORY ${PROJECT_BINARY_DIR}/doc/html
  DESTINATION ${DOC_DIR}/API
  COMPONENT doc CONFIGURATIONS Release)

set(_jekyll_md_file "${PROJECT_BINARY_DIR}/doc/${PROJECT_NAME}-${VERSION_MAJOR}.${VERSION_MINOR}.md")
file(WRITE ${_jekyll_md_file}
"---\n"
"name: ${PROJECT_NAME}\n"
"version: ${VERSION_MAJOR}.${VERSION_MINOR}\n"
"description: ${${UPPER_PROJECT_NAME}_DESCRIPTION}\n"
"issuesurl: ${${UPPER_PROJECT_NAME}_ISSUES_URL}\n"
"packageurl: ${${UPPER_PROJECT_NAME}_PACKAGE_URL}\n"
"maturity: ${${UPPER_PROJECT_NAME}_MATURITY}\n"
"---\n")

if(GIT_DOCUMENTATION_REPO)
  set(_GIT_DOC_SRC_DIR "${PROJECT_SOURCE_DIR}/../${GIT_DOCUMENTATION_REPO}")

  if(IS_DIRECTORY ${_GIT_DOC_SRC_DIR})
    set(GIT_DOCUMENTATION_DIR
      ${_GIT_DOC_SRC_DIR}/${PROJECT_NAME}-${VERSION_MAJOR}.${VERSION_MINOR})
    add_custom_target(${PROJECT_NAME}_doxycopy
      COMMAND ${CMAKE_COMMAND} -E remove_directory ${GIT_DOCUMENTATION_DIR}
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${PROJECT_BINARY_DIR}/doc/html ${GIT_DOCUMENTATION_DIR}
      COMMAND ${CMAKE_COMMAND} -E copy ${_jekyll_md_file} ${_GIT_DOC_SRC_DIR}/_projects
      COMMENT "Copying API documentation to ${GIT_DOCUMENTATION_DIR}"
      DEPENDS ${PROJECT_NAME}_doxygen VERBATIM)
  else()
    add_custom_target(${PROJECT_NAME}_doxycopy
      COMMENT "doxycopy target not available, missing ${_GIT_DOC_SRC_DIR}")
  endif()
else()
  add_custom_target(${PROJECT_NAME}_doxycopy
    COMMENT "doxycopy target not available, missing GIT_DOCUMENTATION_REPO")
endif()

if(NOT TARGET doxycopy)
  add_custom_target(doxycopy)
endif()
add_dependencies(doxycopy ${PROJECT_NAME}_doxycopy)
