name = main
compile_thread = -j8

#if you put the exteranl libaray in one directory
EXT_INCLUDE = $(addprefix -I, $(shell find ${EXT_PATH}/include -maxdepth 1 -type d))
EXT_LIB = -L${EXT_PATH}/lib64/
JIT_LIB = ${EXT_PATH}/lib64/

#if you put the external library seperately in different directories.
#use the following configureaton
# EXT_INC = -I${PNETCDF_INC} -I${ARMA_INC} -I${BOOST_INC} -I${GTEST_INC} -I${JIT_INC}
# EXT_LIB = -L${PNETCDF_LIB} -L${ARMA_LIB} -L${BOOST_LIB} -I${GTEST_LIB} -L${JIT_LIB}


EXT_LIB_LINK = 	-lpnetcdf -lboost_program_options -lboost_filesystem \
		-lboost_system -lboost_log -lboost_log_setup       \
		-lboost_thread  -ldl -ljit -larmadillo \
		-Wl,-rpath=${JIT_LIB}

oplevel0 = -O0 -w -g  -std=c++0x -DBOOST_LOG_DYN_LINK -qopenmp -DSUNWAY
oplevel3 = -O3 -Ofast -xHost -w -g  -std=c++0x -DBOOST_LOG_DYN_LINK -qopenmp -DSUNWAY

FC = mpiifort ${oplevel0}
CC = mpiicc   ${oplevel0}
CXX = mpiicpc ${oplevel0}

FCFLAGS  = 

CXXFLAGS = 

CFLAGS   = 

LIBS =  -lstdc++ ${EXT_LIB} ${EXT_LIB_LINK}

OBJS = $(addsuffix .o,  $(basename $(wildcard *.cpp))) 	\
	$(addsuffix .o, $(basename $(wildcard utils/*.cpp))) 	\
	$(addsuffix .o, $(basename $(wildcard c-interface/*.cpp))) \
	$(addsuffix .o, $(basename $(wildcard modules/*/*.cpp)))

OBJ_FORTRAN_LIB = ${OBJS} \
	$(addsuffix .o, $(basename $(wildcard fortran/*.F90)))

OBJ_FORTRAN = ${OBJ_FORTRAN_LIB} test/oa_test.o test/oa_main.o 

OBJ_MAIN  = ${OBJS} $(addprefix ./test/, main.o)

OBJ_TEST = ${OBJS} $(addprefix ./unittest/, test_array.o gtest_main.o)

OBJ_TEST_PERF = ${OBJS} $(addprefix ./unittest/, test_perf.o)

.DEFAULT_GOAL := all

MAKEFILE = makefile.intel

AA = $(wildcard *.cpp) $(wildcard modules/*/*.cpp)

debug:
	@echo ${OBJS}   

%.o: %.cpp
	$(CXX) ${EXT_INCLUDE} -c $(CXXFLAGS) $< -o $@

%.o: %.c
	$(CXX) ${EXT_INCLUDE} -c $(CFLAGS) $< -o $@

%.o: %.F90
	$(FC) ${FCFLAGS} -c $< -o $@

%.d: %.cpp
	$(CXX) ${EXT_INCLUDE} -c $(CXXFLAGS) $< -o $*.o -MMD

%.d: %.c
	$(CXX) ${EXT_INCLUDE} -c $(CFLAGS) $< -o $*.o -MMD


%.d: %.F90 
	$(FC) ${FCFLAGS} -c $< -o $*.o -gen-dep=$*.d



##===##-include $(OBJ_FORTRAN:.o=.d) 
##===##-include $(OBJ_MAIN:.o=.d) 
##===##-include $(OBJ_TEST:.o=.d) 
##===##-include $(OBJ_TEST_PERF:.o=.d) 


all:
	@rm -rf main
	@echo "Cleaning..."
	@mkdir -p build 
	@./pre.sh
	@cd build && make clean  -f ${MAKEFILE}
	@echo "Cleaning done."
	@cd build && sed -i "s/##===##//g" ${MAKEFILE} && make main ${compile_thread} -f ${MAKEFILE} 
	cp build/main ./

quick:
	@rm -rf ${name}
	@echo "Cleaning..."
	@mkdir -p build 2>/dev/null
	@./test.sh
	@cd build
	@echo "Cleaning done."
	@cd build && sed -i "s/##===##//g" ${MAKEFILE} && make ${name} ${compile_thread} -f ${MAKEFILE}
	@cp build/${name} ./
	@mpirun -oversubscribe -n 8 ./${name} 6 6 6

main: ${OBJ_MAIN} 
	-${CXX} -rdynamic -o main ${OBJ_MAIN} ${LIBS}

testall:
	@rm -rf main
	@echo "Cleaning..."
	@mkdir -p build 2>/dev/null
	@./pre.sh
	@cd build && make clean  -f ${MAKEFILE}
	@echo "Cleaning done."
	@cd build && sed -i "s/##===##//g" ${MAKEFILE} && make testall_main ${compile_thread} -f ${MAKEFILE}
	@cp build/testall_main ./
	@mpirun -np 2 ./testall_main 

testall_main : ${OBJ_TEST}
	-${FC} -o testall_main ${OBJ_TEST} ${LIBS} 

testfortran:
	@rm -rf fortran_main
	@echo "Cleaning..."
	@mkdir -p build 2>/dev/null
	@./pre.sh
	@cd build && make clean  -f ${MAKEFILE}
	@echo "Cleaning done."
	@cd build &&sed -i "s/##===##//g" ${MAKEFILE} && make fortran_main ${compile_thread} -f ${MAKEFILE} 
	@cp build/fortran_main ./
	@mpirun -n 4 ./fortran_main

fortran_main : ${OBJ_FORTRAN}
	-${FC} -o fortran_main ${OBJ_FORTRAN} \
	${EXT_LIB_LINK} ${LIBS} -lgfortran

oalib:
	@rm -rf fortran_main
	@echo "Cleaning..."
	@mkdir -p build 2>/dev/null
	@./pre.sh
	@cd build && make clean  -f ${MAKEFILE}
	@echo "Cleaning done."
	@cd build &&sed -i "s/##===##//g" ${MAKEFILE} && make oalib_obj ${compile_thread} -f ${MAKEFILE} 
	@cp build/libopenarray.a ./

oalib_obj: ${OBJ_FORTRAN_LIB}
	@ar rcs libopenarray.a ${OBJ_FORTRAN_LIB}

small:
	@make all -f ${MAKEFILE}
	@mpirun -n 4 ./main 4 3 2

clean:
	@find . -name "*.o" \
	-or -name "*.d*" \
	-or -name "*.mod" \
	-or -name "main" \
	-or -name "fortran_main" \
	-or -name "testall_main" | \
	xargs rm -f  &>/dev/null
