//c++ `root-config --cflags --libs` -shared -fPIC gen/tchain.cc -o gen/tchain
#include <TChain.h>
extern "C" {
TChain* TChain_TChain1() {
  return new TChain();
}
TChain* TChain_TChain2(const char* name, const char* title) {
  return new TChain(name, title);
}
 Int_t TChain_AddFile1(TChain* __obj, const char* name,  Long64_t nentries, const char* tname) {
  return __obj->AddFile(name, nentries, tname);
}
 Long_t TChain_LoadTree1(TChain* __obj, Long_t entry) {
  return __obj->LoadTree(entry);
}
 Long64_t TChain_GetEntries1(TChain* __obj ) {
 return __obj->GetEntries();
}
 Long64_t TChain_GetEntries2(TChain* __obj, const char* selection) {
  return __obj->GetEntries(selection);
}
 Int_t TChain_GetTreeNumber1(TChain* __obj) {
  return __obj->GetTreeNumber();
}
} //extern C
