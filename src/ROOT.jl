module ROOT

const LIBROOT = string(dirname(Base.source_path()), "/../libroot")

const DUMPEX = ("DUMPEX" in keys(ENV) && int(ENV["DUMPEX"])==1)
"ROOTSYS" in keys(ENV) || error("ROOTSYS not defined, call `source /path/to/root/thisroot.sh`")
import Base.length, Base.getindex

#abstract type that wraps a ROOT object through an opaque pointer
#should implement root_pointer(ROOTObject)::Ptr{Void},
#which returns pointer to ROOT object on heaps
abstract ROOTObject

#custom wrappers

#list of all T-objects that are replaced by Ptr{Void}
const ROOT_OBJECTS = Symbol[]

#is_null(x::TObject) = (x.p==C_NULL || IsZombie(x))
is_null(x::ROOTObject) = x.p==C_NULL
#define a ROOT TObject type, needed for correct dispatch
macro root_object(name)

    parent = symbol("$(name)A")

    push!(ROOT_OBJECTS, name)
    eval(quote
        immutable $name <: $parent
            p::Ptr{Void}
        end
        #$name(p::Ptr{Void}) = $name(p)
        function root_pointer(x::$name)
            assert(x.p != 0)
            return x.p
        end
    end)
end

#FIXME: this is somewhat arbitrary
const kBigNumber = 10^8

#hand-coded class hierarchy
#FIXME: autogen these
abstract TObjectA <: ROOTObject
abstract TClassA <: TObjectA
abstract TArrayA
abstract TArrayDA <: TArrayA

abstract TDirectoryA <: TObjectA
abstract TFileA <: TDirectoryA

abstract TKeyA <: TObjectA
abstract TBranchA <: TObjectA
abstract TLeafA <: TObjectA

abstract TTreeA <: TObjectA
abstract TChainA <: TTreeA

abstract TCollectionA <: TObjectA
abstract TSeqCollectionA <: TCollectionA
abstract TObjArrayA <: TSeqCollectionA
abstract TListA <: TObjArrayA

abstract TListIterA <: TObjectA

abstract TH1A <: TObjectA
abstract TH1DA <: TH1A

abstract TH2A <: TH1A
abstract TH2DA <: TH2A

abstract TH3A <: TH1A
abstract TH3DA <: TH3A

abstract TUnfoldA <: TObjectA
abstract TUnfoldSysA <: TUnfoldA

root_cast{T <: ROOTObject, K <: ROOTObject}(to::Type{K}, o::T) =
    to(root_pointer(o))

#FIXME: autogenerate
@root_object(TObject)

@root_object(TClass)

@root_object(TFile)
@root_object(TDirectory)

@root_object(TCollection)
@root_object(TSeqCollection)
@root_object(TObjArray)
@root_object(TList)
@root_object(TListIter)
@root_object(TKey)
@root_object(TArray)
@root_object(TArrayD)

@root_object(TBranch)
@root_object(TLeaf)
@root_object(TTree)
@root_object(TChain)

@root_object(TH1)
@root_object(TH1D)
#FIXME: silent case of TH1F to TH1D, may not work on all systems
typealias TH1F TH1D

@root_object(TH2)
@root_object(TH2D)

@root_object(TH3)
@root_object(TH3D)

@root_object(TUnfold)
@root_object(TUnfoldSys)
#FIXME: silent case of TH2F to TH2D, may not work on all systems
typealias TH2F TH2D

typealias TH3F TH3D

#these will be overridden using type_replacement
abstract Option_t
abstract Int_t
abstract UInt_t
abstract Long_t
abstract Long64_t
abstract Double_t
abstract Float_t
abstract Bool_t
abstract Char_t

const kFALSE = false
const kTRUE = true
const kIterForward = true

const type_replacement = Dict{Any,Any}(
    #:Option_t                => :(Ptr{Uint8}),
    :(Ptr{None})              => :(Ptr{Void}),
    :Int_t                    => :Cint,
    :UInt_t                   => :Cuint,
    :Long_t                   => :Clong,
    :Long64_t                 => :Clonglong,
    :Double_t                 => :Cdouble,
    :Float_t                  => :Cfloat,
    :Bool_t                   => :Bool,
    :Char_t                   => :Cchar,
    :UChar_t                  => :Cuchar,
    :(Ptr{Option_t})          => :ASCIIString,
    :(Ptr{Uint8})             => :ASCIIString,
    :(Ptr{Double_t})          => :(Ptr{Cdouble}),
    :(Ptr{Float_t})           => :(Ptr{Cfloat}),
    :(Ptr{UInt_t})            => :(Ptr{Cuint}),

    :TH2D                     => :TH2DA,
    :TH2                      => :TH2A,
    
    :TH3D                     => :TH3DA,
    :TH3                      => :TH3A,

    :TH1D                     => :TH1DA,
    :TH1                      => :TH1A,
    :TFile                    => :TFileA,
    :TDirectoryFile           => :TDirectoryFileA,
    :TDirectory               => :TDirectoryA,

    :TCollection              => :TCollectionA,
    :TSeqCollection           => :TSeqCollectionA,
    :TList                    => :TListA,

    :TObject                  => :TObjectA,

    :TTree                    => :TTreeA,
    :TChain                   => :TChainA,
    :None                     => :Void
)

const ccall_type_replacement = Dict{Any,Any}(
    :ASCIIString        =>    :(Ptr{Uint8}),
    :(Ptr{Option_t})    =>    :(Ptr{Uint8}),
    #:(Ptr{None})        =>    :(Ptr{Void}),
    :Int_t              =>    :Cint,
    :UInt_t             =>    :Cuint,
    :Long_t             =>    :Clong,
    :Long64_t           =>    :Clong,
    :Double_t           =>    :Cdouble,
    :Float_t            =>    :Cfloat,
    :Bool_t             =>    :Bool,
    :(Ptr{Double_t})    =>    :(Ptr{Float64}),
    :(Ptr{Float_t})     =>    :(Ptr{Float32}),
)

#replaces argument list expressions from ROOT->Julia
#input:
#    :(a1::Ptr{Uint8}, ...)
#outputs:
#    :(a1, ...), => for ccall values
#    :(Ptr{Uint8}, ...), => for ccall types
#    :(a1::ASCIIString, ...), => for julia function arguments
function argument_replace(args::Expr)

    #println(args.args)

    #argument values
    avals = Expr(:tuple)
    #argument types
    aargs = Expr(:tuple)
    #value::Type with possible julia-side replacements
    jlargs = Expr(:tuple)

    #loop over argument list
    for a in args.args

        #must be typed argument
        (isa(a, Expr) && a.head == symbol("::")) || error("$a is not typed")

        #name, type
        n = a.args[1]
        t = a.args[2]

        jt = t

        ###
        #conversions for julia-side function argument types
        ###
        if haskey(type_replacement, jt)
            const jt_ = type_replacement[jt]
            #println("replacing $jt with $jt_")
            jt = jt_
        end

        if jt == :(Ptr{TList})
            #println("TList pointer $jt, $n, $t")
            jt = :(Ptr{Void})
            t = :(Ptr{Void})
        end

        ##replace C-Uint8 with julia ASCIIString
        ##x::Ptr{Uint8}(const char *) => x::ASCIIString
        #if (eval(t) == Ptr{Uint8})
        #    jt = :(ASCIIString)
        #end

        ##cast ROOT Int32 to Int64 in julia arguments
        #if eval(t) == Int32 || eval(t) == Cint
        #    jt = :(Int64)
        #end

        ###
        #conversions for ccall argument types
        ###

        #strings passed from julia are Ptr{Uint8} in ccall
        if haskey(ccall_type_replacement, t)
            t = ccall_type_replacement[t]
        end

        #put julia arguments back together
        jlarg = Expr(symbol("::"))
        push!(jlarg.args, n)
        push!(jlarg.args, jt)

        if typeof(t) <: Symbol
            if t in ROOT_OBJECTS
                n = :(root_pointer($(n)))
                t = :(Ptr{Void})
            end
        elseif typeof(t) <: Expr
            #if t.head == :curly && t.args[1] == :Ptr
            #    n = :(root_pointer($(n)))
            #    t = :(Ptr{Void})
            #end
        end
        #println("found replacement $n::$t")

        push!(avals.args, n)
        push!(aargs.args, t)

        push!(jlargs.args, jlarg)
        #println("$n $t $jlarg")
    end
    return avals, aargs, jlargs
end

function splice_kwargs(jlargs::Expr, defs::Expr)
    #default values
    #println("defs=$defs")
    defs = eval(defs)
    for i=1:length(defs)
        d = defs[i]

        #const char* x=0 ===> x::ASCIIString=""
        t = eval(jlargs.args[i].args[2])::Type
        if t <: ASCIIString && typeof(d) <: Integer
            d = ""
        end

        if d != nothing
            try
                convert(t, d)
                #println("d=$d::", typeof(d))
                jlargs.args[i] = Expr(:kw, jlargs.args[i], convert(t, d))
            catch err
                #println("could not cast: ", jlargs.args[i], " $err $t $d")
                jlargs.args[i] = Expr(:kw, jlargs.args[i], d)
            end
        end
    end
    return jlargs
end

#maps :libroot -> /full/path/to/libroot
function define_lib(lib::Expr)
    lib = lib.args[1]

    if !isdefined(lib)
        q = quote
        const $(symbol(string(lib))) = joinpath(
            dirname(Base.source_path()), "..",
            $(string(lib))
        )
        end
        eval(q)
    end
end
define_lib(lib::Symbol) = lib

#macro to make methods from
#@method libname Type ReturnType julia__function__name (c_arg1, ...) c__function__name
macro method(lib, tgt, jlfunc, ret, args, cfunc, defs)
    define_lib(lib)

    avals, aargs, jlargs = argument_replace(args)
    jlargs = splice_kwargs(jlargs, defs)

    #C function name target_func
    cfname = "$(tgt)_$(cfunc)"

    r = eval(ret)
    wrapped_return = false
    rettype = nothing
    #Replace return type Ptr{X<:TObject} (C) => X (julia)
    if r <: Ptr && typeof(r)==DataType && r.parameters[1] in map(eval, ROOT_OBJECTS)
        if jlfunc == :Next
            ret = :(Ptr{Void})
        else
            ret = r.parameters[1]
        end
        #wrapped_return = true
        #rettype = r.parameters[1]
        #ret = :(Ptr{Void})
    end

    if tgt in keys(type_replacement)
        tgt = type_replacement[tgt]
    end

    #println("ret $(typeof(ret)) $ret $r")
    if ret in keys(type_replacement) && ret != :(Ptr{Uint8})
        ret = type_replacement[ret]
    end
    #println("ret replaced $ret")

    if !wrapped_return
        #create a function "stub"
        ex = quote
            function $jlfunc(__obj::$tgt)
                @assert(__obj.p != C_NULL)
                ccall(
                    ($cfname, LIBROOT),
                    $(eval(ret)), (),
                )
            end
        end
    end

    #println("args=", ex.args)
    #Note, this is fragile. if the stub is changed, the argument indices will also
    
    #splice julia function args
    append!(ex.args[2].args[1].args, jlargs.args)
    #splice C function argument types
    append!(ex.args[2].args[2].args[4].args[3].args, [:(Ptr{Void})]) #object itself
    append!(ex.args[2].args[2].args[4].args[3].args, aargs.args) #args
    #splice C function argument values
    append!(ex.args[2].args[2].args[4].args, [:(__obj.p)]) #object itself
    append!(ex.args[2].args[2].args[4].args, avals.args)

    DUMPEX && println(ex)
    eval(ex)
end


#currently a placeholder
macro subclass(p1, p2)
end

#macro to make constructors from
#@constructor libname Type (c_arg1, ...) c__function__name
# => :ccall( (c__function__name, libname), Ptr{Void}, (args...), argsvals...)
macro constructor(lib, cls, args, cfunc, defs)
    define_lib(lib)

    avals, aargs, jlargs = argument_replace(args)
    jlargs = splice_kwargs(jlargs, defs)

    #C function name target_func
    cfname = "$(cls)_$(cfunc)"

    #create a function "stub"
    ex = quote
        function $cls()
            ccall(
                ($cfname, LIBROOT),
                $(eval(cls)), (),
            )
        end
    end


    # splice julia function args
    # FIXME: this is fragile. if the stub is changed, the argument indices will
    # also change
    append!(ex.args[2].args[1].args, jlargs.args)
    append!(ex.args[2].args[2].args[2].args[3].args, aargs.args)
    append!(ex.args[2].args[2].args[2].args, avals.args)
    DUMPEX && println(ex)
    eval(ex)
end

include("../gen/groot.jl")
include("../gen/tobject.jl")

include("../gen/tcollection.jl")
include("../gen/tseqcollection.jl")
include("../gen/tlist.jl")
include("../gen/tkey.jl")
include("../gen/tarrayd.jl")

include("../gen/th1.jl")
include("../gen/th1d.jl")

include("../gen/th2.jl")
include("../gen/th2d.jl")

include("../gen/th3.jl")
#include("../gen/th3d.jl")

include("../gen/tdirectory.jl")
include("../gen/tfile.jl")

include("../gen/tlistiter.jl")

include("../gen/ttree.jl")
include("../gen/tchain.jl")
include("../gen/tbranch.jl")
include("../gen/tleaf.jl")

include("../gen/tunfold.jl")
include("../gen/tunfoldsys.jl")

function Base.length(x::TCollectionA)
    if x.p != C_NULL
        return GetEntries(x)
    else
        warn("collection $x is invalid")
        return 0
    end
end

##ROOT is zero-based, Julia one-based
Base.getindex(tc::TSeqCollectionA, n::Integer) = At(tc, int32(n-1))

ReadObj(x) = ReadObj(root_cast(TKey, x))

#might be needed in some cases
#@linux_only begin
#    #for some reason, libRIO is not properly loaded on linux
#    const rio = joinpath(ENV["ROOTSYS"], "lib", "libRIO.so")
#    gROOT.process_line(".L $rio")
#    gROOT.process_line(".L $rio")
#end

#short type names used in ROOT's TBranch constructor for the leaflist
const SHORT_TYPEMAP = Dict{DataType, ASCIIString}(
    Float32   => "F",
    Float64   => "D",
    Int32     => "I",
    Int64     => "L",
    Uint64    => "l",
    Uint8     => "C",
    Char      => "C",
    Bool      => "O"
)

classname(o) = ClassName(root_cast(TObject, o))|>bytestring;

function to_root(h)
    cn = classname(h)
    T = eval(parse(cn))::Type
    h = root_cast(T, h)::T
end

import Base.mkpath
function Base.mkpath(tf::TFile, dirname; cd=true)
    assert(!is_null(tf)) 
    Cd(tf, "")
    is_null(Get(tf, dirname)) && mkdir(tf, dirname)
    d = root_cast(TDirectory, Get(tf, dirname))
    if cd
        Cd(tf, "")
        Cd(tf, "/$dirname")
    end
    return d
end

export TFile, TTree, TObject, TH1, TH1F, TH2F, TH3F, TH1D, TH2D, TH2, TH3D, TBranch, TKey, TLeaf, TDirectory, TClass
export TFileA, TTreeA, TObjectA, TH1A, TH2A, TH3A, TBranchA, TKeyA, TLeafA, TDirectoryA, TClassA
export TChain
export Open
export Write, Close, Fill, Branch, Print
export GetListOfBranches, GetEntry, GetEvent, SetBranchAddress
export GetListOfKeys, Get, GetList
export GetTreeNumber
export Cd, mkdir

export AddFile

export SetAddress, GetBranch, GetClassName, GetListOfLeaves
export GetTypeName

export SetCacheSize, AddBranchToCache, SetBranchStatus, Draw, GetV1
export ReadObj, GetName, ClassName
export Integral, GetEntries, SetEntries, GetNbinsX, GetNbinsY, GetNbinsZ, GetBinContent, GetBinError, GetBinLowEdge, GetBinWidth
export Chi2Test
export SetBinContent, SetBinError
export SetDirectory
export GetRMS, GetMean
export LoadTree

#"global" methods
export root_cast
export gROOT

export classname, to_root
export SHORT_TYPEMAP

export GetAt, SetAt, GetSize
export Sumw2, GetSumw2

export TListIter, Next, Reset
export is_null

#include("ROOTHistograms.jl")

end
