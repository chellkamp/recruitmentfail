using System.Runtime.Serialization;

namespace RecruitmentFailWeb.Util
{
    public class ReasonException : Exception
    {
        public ReasonException() { }

        public ReasonException(string? message) : base(message) { }

        public ReasonException(string? message, Exception? innerException) : base(message, innerException) { }

        public ReasonException(SerializationInfo info, StreamingContext context) : base(info, context) { }

    }
}
