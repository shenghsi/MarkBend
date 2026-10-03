import Base
import ./DocumentBench.bend as Fixture
import ./FixtureCheck.bend as Reference
import ./DirectCheck.bend as Check

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(Reference.source_matches(Fixture.sample(0n), Reference.create(0n), 0n))
    Check.check(Reference.source_matches(Fixture.sample(130n), Reference.create(130n), 0n))
    Check.check(Reference.source_matches(Fixture.sample(102400n), Reference.create(102400n), 0n))
    Check.check(Reference.source_matches(Fixture.sample(1048576n), Reference.create(1048576n), 0n))
    IO.print("Exact Markdown fixture generation check passed")
