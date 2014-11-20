//c++ `root-config --cflags --libs` -shared -fPIC gen/tleaf.cc -o gen/tleaf
#include <TLeaf.h>
extern "C" {
const char* TLeaf_GetTypeName1(TLeaf* __obj ) {
  return __obj->GetTypeName();
}
void* TLeaf_GetLeafCount1(TLeaf* __obj ) {
  return __obj->GetLeafCount();
}
Int_t TLeaf_GetLenStatic1(TLeaf* __obj ) {
  return __obj->GetLenStatic();
}
} //extern C
