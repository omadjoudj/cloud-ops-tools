alias silences="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence"
alias silence-add="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence add -a '<YOUR_NAME>' -d '2h'"

silence-add -c "Comment" alertname=~".+"
