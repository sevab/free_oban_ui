# FreeObanUi: Unofficial UI for Oban - Job Processor for Elixir projects

This is a free working unofficial Web UI for [Oban Job Processor](https://github.com/oban-bg/oban), allowing you to view jobs in different states (executing, scheduled, retryable, cancelled, discarded, complete) and perform basic operations (run, delete, retry, etc)

![View all jobs](free_oban_ui/assets/img/index.png)
![View individual job](free_oban_ui/assets/img/show.png)


Designed for hobby projects or if you cannot afford paid Oban Web. Please make sure to support & buy official Oban UI package if you can: https://getoban.pro/

Right now this is designed as a sample LiveView app, with all relevant code living `/lib/free_oban_ui_web/live/oban_live/` (extracted from a real app - so the code is working) + the routes defined in `router.ex`. However, I would like to update this package, so that you can import these Live Routes into any Phoenix app. I've never built a LiveView library before, so help/PRs are appreciated to get this working.

Other things that need help:
* Implement bulk action updates on multiple jobs at once - UI is already there, but the LiveView logic of selecting/deselecting individual/all jobs is not.