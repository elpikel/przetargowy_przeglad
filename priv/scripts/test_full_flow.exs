# Run: mix run priv/scripts/test_full_flow.exs

alias PrzetargowyPrzeglad.Workers.{FetchTendersWorker, GenerateNewsletterWorker, SendNewsletterWorker}
alias PrzetargowyPrzeglad.{Subscribers, Tenders, Newsletters}

IO.puts("=== FULL FLOW TEST ===\n")

# 1. Dodaj testowego subskrybenta
IO.puts("1. Creating test subscriber...")
{:ok, subscriber} = Subscribers.subscribe(%{
  email: "test@example.com",
  name: "Test User"
})
IO.puts("   Created: #{subscriber.email} (#{subscriber.status})")

# 2. Potwierdź subskrypcję
IO.puts("\n2. Confirming subscription...")
{:ok, subscriber} = Subscribers.confirm_subscription(subscriber.confirmation_token)
IO.puts("   Status: #{subscriber.status}")

# 3. Pobierz przetargi
IO.puts("\n3. Fetching tenders...")
{:ok, job} = FetchTendersWorker.enqueue(days: 7, max_pages: 3)
IO.puts("   Job enqueued: #{job.id}")
# Wait for job to complete
Process.sleep(10_000)
IO.puts("   Tenders in DB: #{Tenders.count_all()}")

# 4. Generuj newsletter
IO.puts("\n4. Generating newsletter...")
{:ok, job} = GenerateNewsletterWorker.enqueue()
IO.puts("   Job enqueued: #{job.id}")
Process.sleep(3_000)
newsletter = Newsletters.get_latest()
IO.puts("   Newsletter ##{newsletter.issue_number} - #{newsletter.status}")

# 5. Wyślij newsletter (do lokalnego mailbox)
IO.puts("\n5. Sending newsletter...")
{:ok, job} = SendNewsletterWorker.enqueue()
IO.puts("   Job enqueued: #{job.id}")
Process.sleep(5_000)
newsletter = Newsletters.get_latest()
IO.puts("   Newsletter status: #{newsletter.status}")
IO.puts("   Recipients: #{newsletter.recipients_count}")

IO.puts("\n=== TEST COMPLETE ===")
IO.puts("Check /dev/mailbox to see the email!")
