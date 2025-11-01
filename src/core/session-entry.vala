namespace Pomodoro
{
    public class SessionEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 start_time { get; set; }
        public int64 end_time { get; set; }
        public int64 expiry_time { get; set; }

        internal ulong version = 0;

        static construct
        {
            set_table ("sessions");
            set_primary_key ("id");
            set_notnull ("start-time");
            set_notnull ("end-time");
            set_notnull ("expiry-time");
            set_unique ("start-time");
        }
    }
}
