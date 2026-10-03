import Base
import ./Utf8.bend as Utf8
import ./ResolvedOpen.bend as Path

type Choice is Data:
  Disabled{}
  Enabled{host: String, root: String}
  Invalid{message: String}
  Unavailable{host: String, root: String}

def available(supported: Bool, host: String, root: String) -> Choice:
  match supported:
    case True{}: Enabled{host, root}
    case False{}: Unavailable{host, root}

def paths(valid: Bool, supported: Bool, host: String, root: String) -> Choice:
  match valid:
    case True{}: available(supported, host, root)
    case False{}: Invalid{"Recovery host and catalog root must be nonempty paths without NUL"}

def decoded(host: Maybe<&2, String>, root: Maybe<&2, String>, supported: Bool) -> Choice:
  match host root:
    case Some{+program} Some{+directory}:
      paths(Bool.not(String.is_empty(program)) && Bool.not(String.is_empty(directory)) &&
        Path.no_nul(program, True{}) && Path.no_nul(directory, True{}), supported, program, directory)
    case _ _:
      Invalid{"Recovery settings are not valid UTF-8"}

def configured(value: Maybe<List<&2, U32>> & Maybe<List<&2, U32>>, supported: Bool) -> Choice:
  match value:
    case (None{}, None{}): Disabled{}
    case (Some{host}, Some{root}):
      host_text root_text = Utf8.decode(host) Utf8.decode(root)
      decoded(host_text, root_text, supported)
    case _: Invalid{"Set both the recovery host and catalog root"}

# This is an explicit experiment setting. It grants no file write permission.
def decode(value: Result<&1, &1, U32 & String,
  Bool & (Maybe<List<&2, U32>> & Maybe<List<&2, U32>>)>) -> Choice:
  match value:
    case Done{(supported, config)}: configured(config, supported)
    case Fail{(code, message)}: Invalid{message}
