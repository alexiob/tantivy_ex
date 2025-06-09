# Suppress info logs during tests to keep output clean
Logger.configure(level: :warning)

ExUnit.start()
