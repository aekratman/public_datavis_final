
# just for fun -- see project process book for details!

# ------------------------ BARRIER SO ABBEY DOESN'T LOSE IT ------------------------ 
# llm

output$llm_summary <- renderUI({

  yearly <- assault_clean %>%
    group_by(Year) %>%
    summarise(count = n(), .groups = "drop")

  hourly <- assault_clean %>%
    group_by(hour) %>%
    summarise(count = n(), .groups = "drop")

  peak_hour <- hourly %>%
    arrange(desc(count)) %>%
    slice(1) %>%
    pull(hour)

  prompt <- paste0(
    "You are a professional crime data analyst.\n",
    "Write in Markdown format using headings and bullets.\n\n",
    "Format tables using Markdown pipe syntax (| columns |).",
    "YEARLY TRENDS:\n",
    paste(capture.output(print(yearly)), collapse = "\n"),
    "\n\nHOURLY PEAK: ", peak_hour,
    "\n\nWrite analysis."
  )

  text <- query_mistral(prompt)

  HTML(markdown::markdownToHTML(
    text = text,
    fragment.only = TRUE
  ))
})