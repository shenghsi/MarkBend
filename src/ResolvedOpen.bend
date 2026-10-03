import Base
import ./DocumentOpen.bend as Open
import ./AppDocument.bend as App
import ./StoredEditor.bend as Editor
import ./SaveState.bend as Save
import ./Utf8.bend as Utf8

type Raw is Data:
  Raw{requested: String, path: List<&2, U32>, identity: List<&2, U32>, bytes: List<&2, U32>}

type Reason is Data:
  InvalidPath{}
  InvalidIdentity{}
  TooLarge{}
  InvalidUtf8{}

type Outcome is Data:
  Opened{document: App.Document}
  Rejected{raw: Raw, reason: Reason}
  ReadFailed{requested: String, code: U32, message: String}

def valid_bytes(bytes: List<&2, U32>, ok: Bool) -> Bool:
  match bytes ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      True{}
    case byte <> rest True{}:
      valid_bytes(rest, U32.is_le(byte, 255))

def no_nul(path: String, ok: Bool) -> Bool:
  match path ok:
    case _ False{}:
      False{}
    case SNil{} True{}:
      True{}
    case SCon{char, rest} True{}:
      no_nul(rest, Bool.not(Char.is_eq(char, Chr{0})))

def loaded(value: Maybe<&2, Editor.Session>, raw: Raw, path: String) -> Outcome:
  match value raw:
    case None{} raw:
      Rejected{raw, InvalidUtf8{}}
    case Some{session} Raw{requested, path_bytes, identity, bytes}:
      Opened{App.Document{App.Resolved{requested, path, identity}, session}}

def bounded(fits: Bool, +raw: Raw, path: String) -> Outcome:
  match fits raw:
    case False{} raw:
      Rejected{raw, TooLarge{}}
    case True{} Raw{requested, path_bytes, identity, bytes}:
      loaded(Editor.load(Save.open(bytes)), raw, path)

def path_checked(valid: Bool, +raw: Raw, path: String) -> Outcome:
  match valid raw:
    case False{} raw:
      Rejected{raw, InvalidPath{}}
    case True{} Raw{requested, path_bytes, identity, bytes}:
      bounded(Open.fits(8388608n, bytes), raw, path)

def decoded_path(value: Maybe<&2, String>, raw: Raw) -> Outcome:
  match value:
    case None{}:
      Rejected{raw, InvalidPath{}}
    case Some{+path}:
      path_checked(Bool.not(String.is_empty(path)) && no_nul(path, True{}), raw, path)

def identified(valid: Bool, +raw: Raw) -> Outcome:
  match valid raw:
    case False{} raw:
      Rejected{raw, InvalidIdentity{}}
    case True{} Raw{requested, path, identity, bytes}:
      decoded_path(Utf8.decode(path), raw)

# A host identity remains opaque. It grants no save or recovery permission.
def decode(+raw: Raw) -> Outcome:
  match raw:
    case Raw{requested, path, +identity, bytes}:
      identified(Bool.not(List.is_empty(&2, U32, identity)) && valid_bytes(identity, True{}), raw)

def received(value: Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>, requested: String) -> Outcome:
  match value:
    case Fail{(code, message)}:
      ReadFailed{requested, code, message}
    case Done{(path, (identity, bytes))}:
      decode(Raw{requested, path, identity, bytes})
