using Microsoft.AspNetCore.Mvc.Filters;
using System.Net;

namespace RecruitmentFailWeb.Util
{
    public class ExceptionLoggerAttribute : IExceptionFilter
    {
        private readonly ILogger<ExceptionLoggerAttribute> _logger;

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="logger">logger object</param>
        public ExceptionLoggerAttribute(ILogger<ExceptionLoggerAttribute> logger)
        {
            _logger = logger;
        }

        public void OnException(ExceptionContext context)
        {
            Exception ex = context!.Exception;
            String? path = context?.HttpContext?.Request?.Path;

            String logMessage = path != null ? $"Error thrown calling path {path}" : "Error thrown";

            _logger.LogError(ex, logMessage);


            ReasonException? reasonException = ex as ReasonException;

            String title = String.Empty;
            String message = "Whoops!  An error occurred!  Sorry about that!";

            if (reasonException != null)
            {
               message = reasonException.Message;
            }

            context!.ExceptionHandled = true;
            context!.HttpContext!.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
            context!.HttpContext!.Response.WriteAsync(message);
        }
    }
}
