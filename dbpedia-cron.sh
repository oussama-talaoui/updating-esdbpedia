echo "Creating a cron job for updating Spanish Dbpedia."

read -p "Enter month ( 1 to 12 from January to December, empty or * for ever month): " month
while [[ ! $month =~ ^[0-9]+$ || ! $month -ge 1 || ! $month -le 12 ]]
do
    if [[ $month == '' || $month == '*' ]]
	then
		month='*'
	break
    fi
    printf 'Please enter a valide month number: '
    read month
done

read -p "Enter weekday (0 to 6 from Sunday to Saturday, empty or * for ever weekday): " weekday
while [[ ! $weekday =~ ^[0-9]+$ || ! $weekday -ge 0 || ! $weekday -le 6 ]]
do
    if [[ $weekday == '' || $weekday == '*' ]]
	then
		weekday='*'
	break
    fi
    printf 'Please enter a valide weekday: '
    read weekday
done

read -p "Enter day of the month (1 to 31, empty or * for everyday): " day
while [[ ! $day =~ ^[0-9]+$ || ! $day -ge 1 || ! $day -le 31 ]]
do
    if [[ $day == '' || $day == '*' ]]
	then
		day='*'   
	break
    fi
    printf 'Please enter a valide day: '
    read day
done

read -p "Enter hour of the day (0 to 24, empty or * for every hour): " hour
while [[ ! $hour =~ ^[0-9]+$ || ! $hour -ge 0 || ! $hour -le 24 ]]
do
    if [[ $hour == '' || $hour == '*' ]]
	then
		hour='*'
	break
    fi
    printf 'Please enter a valide hour: '
    read hour
done

read -p "Enter minute (0 to 59, empty or * for every minute): " minute
while [[ ! $minute =~ ^[0-9]+$ || ! $minute -ge 0 || ! $minute -le 59 ]]
do
    if [[ $minute == '' || $minute == '*' ]]
	then
		minute='*'
	break
    fi
    printf 'Please enter a valide minute: '
    read minute
done

timestamp='$(date "+\%Y.\%m.\%d-\%H.\%M.\%S")'
# Backslash used to escape % which is a new line in ts command (ts from moreutils: $ sudo apt-get install moreutils)
mkdir -p log
cronjob="$minute $hour $day $month $weekday update-script.sh | ts '[\%Y-\%m-\%d \%H:\%M:\%S]' >> log/"$timestamp"_esdbpedia-update.log 2>&1; echo $? | ts '[\%Y-\%m-\%d \%H:\%M:\%S]' >> log/"$timestamp"_code-error.log"

cronexists='echo Cron job for this file already exists!
read -p "Do want to remove it (y/n)? " -n 1 -r
echo 
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
else
    crontab -r
fi
read -p "Do want to create this new cron job (y/n)? " -n 1 -r
echo 
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
else
    { echo "$cronjob"; } | crontab -
fi
'

chmod +x update-script.sh

echo "Your cron job command is: $cronjob"
crontab -l | grep -q 'update-script.sh' && eval "$cronexists" || { echo "$cronjob"; } | crontab -