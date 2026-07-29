#include <mcl/bn.h>

extern "C" __attribute__((visibility("default"))) bool mcl_plugin_init()
{
	return mclBn_init(mclBn_CurveSNARK1, MCLBN_COMPILED_TIME_VAR) == 0;
}
