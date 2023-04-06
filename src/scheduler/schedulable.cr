# Interface for a schedulable object. For example `CRON`.
module Schedulable
  # Returns the next occurrence at which the scheduled object must be run,
  # relative to the passed time instance (must default to `Time.local`).
  abstract def next(t : Time = Time.local) : Time
end
