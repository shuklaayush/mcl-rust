#include <dlfcn.h>
#include <mcl/bn.h>

#include <cstdlib>
#include <iostream>

int main(int argc, char* argv[])
{
	if (argc != 2) {
		std::cerr << "usage: mcl-host <plugin>\n";
		return EXIT_FAILURE;
	}
	if (mclBn_init(mclBn_CurveSNARK1, MCLBN_COMPILED_TIME_VAR) != 0) {
		std::cerr << "host mclBn_init failed\n";
		return EXIT_FAILURE;
	}

	void* library = dlopen(argv[1], RTLD_NOW);
	if (library == nullptr) {
		std::cerr << "dlopen failed: " << dlerror() << '\n';
		return EXIT_FAILURE;
	}
	auto plugin_init = reinterpret_cast<bool (*)()>(dlsym(library, "mcl_plugin_init"));
	if (plugin_init == nullptr || !plugin_init()) {
		std::cerr << "plugin initialization failed\n";
		return EXIT_FAILURE;
	}
	if (dlclose(library) != 0) {
		std::cerr << "dlclose failed: " << dlerror() << '\n';
		return EXIT_FAILURE;
	}
	return EXIT_SUCCESS;
}
