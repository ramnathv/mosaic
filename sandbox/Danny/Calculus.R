#' Derivative and Anti-derivative operators
#' 
#' Operators for computing derivatives and anti-derivatives as 
#' functions.
#'
#' @rdname Calculus
#'
#' @param formula A formula. The right side specifies the variable(s) with which to 
#'   carry out the integration or differentiation.  On the left side should be 
#'   an expression or a function that returns a numerical vector 
#'   of the same length as its argument.  The expression can contain unbound variables.
#'
#' @param \dots Default values to be given to unbound variables in the expression \code{expr}.  
#' See examples.  
#'
#' @param .hstep  horizontal distance between points used for secant slope
#'   calculation in numerical derivatives. 
#'   
#' @param add.h.control logical indicating whether the returned derivative function
#'   should have an additional parameter for setting .hstep.  Meaningful only for numerical
#'   derivatives.
#'   

#' @return For derivatives, the return value is a function of the variable(s)
#' of differentiation, as well as any other symbols used in the expression.  Thus,
#' \code{D(A*x^2 + B*y ~ x + y)} will compute the mixed partial with respect to x
#' then y (that is, \eqn{\frac{d^2 f}{dy\;dx}}{d2f/dydx}).  The returned value will be a function of x and y,
#' as well as A and B.  In evaluating the returned function, it's best to use the
#' named form of arguments, to ensure the order is correct.
#' 
#' @details
#' \code{D} attempts to find a symbolic derivative for simple expressions, but
#' will provide a function that is a numerical derivative if the attempt at
#' symbolic differentiation is unsuccessful.  The symbolic derivative can be of
#' any order (although the expression may become unmanageably complex).  The
#' numerical derivative is limited to first or second-order partial derivatives
#' (including mixed partials).
#' 
#' \code{antiD} returns a function with arguments \code{to} 
#' and \code{from=0}, the upper and lower
#' bounds of the interval of integration w.r.t. the variable of integration.
#' The numerical value of the integral or
#' derivative can be found by evaluating that function against its inputs.
#' @author Daniel Kaplan (\email{kaplan@@macalester.edu}) 
#' 
#' @export
#' @examples
#' D(sin(t) ~ t)
#' D(A*sin(t) ~ t )
#' D(A*sin(2*pi*t/P) ~ t, A=2, P=10) # default values for parameters.
#' f <- D(A*x^3 ~ x + x, A=1) # 2nd order partial -- note, it's a function of x
#' f(x=2)
#' f(x=2,A=10) # override default value of parameter A
#' g <- D(f(x=t, A=1)^2 ~ t)  # note: it's a function of t
#' g(t=1) 
#' gg <- D(f(x=t, A=B)^2 ~ t, B=10)  # note: it's a function of t and B
#' gg(t=1)
#' gg(t=1, B=100)
#' 
#' @keywords calculus 
#'
D <- function(formula, ..., .hstep=NULL,add.h.control=FALSE){
  formulaEnv = environment(formula) # where was the formula made?
  #Try to construct a symbolic derivative
  res = try(symbolicD(formula, ...), silent=TRUE)
  #Failed?  Do it numerically  
  if( inherits(res, "try-error") ) # symbolic attempt unsuccessful
    res = numD( formula, ..., .hstep=.hstep, add.h.control=add.h.control)
  
  environment(res) = formulaEnv # function should refer to environment of the formula
  return(res)
}
# ============================
antiD <- function(formula, ...){
  wrt <- all.vars(rhs(formula), unique=FALSE) # "with respect to" variable name
  if (length(wrt) != 1)  stop("Integration with respect to multiple variables not supported directly.")
  f <- makeFun(formula, ..., strict.declaration=FALSE)
  # NOTE: Don't use NULL as the default value.  Non-NULL is needed
  # so that the argument list gets created appropriately
  vi.from <- inferArgs( wrt, list(...), defaults=alist(val=0), 
                        variants = c("from",".from"))$val
  vi.to <- inferArgs( wrt, list(...), defaults=alist(val=NaN), 
                      variants = c("to",".to"))$val
  return(makeAntiDfun(f, wrt, vi.from, vi.to, 1e-6))
}
# ===================
# The function returned by antiD will take the same arguments as
# f, but will split one of the variables into a "to" and "from" component. 
# The "from" will have a default value of 0 or otherwise inherited from 
# the call to antiD
# The variable of integration will be called "viName"

makeAntiDfun <- function(.function, .wrt, from, to, .tol) { 
  # Combine default args with those given in the function call
  res <- function() {
    numerical.integration(.function,.wrt, 
                          as.list(match.call())[-1],formals())
  }
  resargs <- formals(.function) 
  resargs[[.wrt]] <- NULL
  limitsArgs = list()
  limitsArgs[[paste(.wrt,".to",sep="")]] <- to # should come first
  limitsArgs[[paste(.wrt,".from",sep="")]] <- from # should come second
  formals(res) <- c(limitsArgs,resargs)
  return(res)
}
# =============
numerical.integration <- function(f,wrt,av,args) {
  # Extract the limits from the argument list
  av2 = c(av, args) # combine the actual arguments with the formals
  # to make sure that default values are included
  vi.from <- inferArgs(wrt, av2, defaults=alist(val=NaN), 
                       variants = c("from",".from"))$val
  vi.to <- inferArgs(wrt, av2, defaults=alist(val=NaN), 
                     variants = c("to",".to"))$val
  browser()
  if( is.nan(vi.to) | is.nan(vi.from)) stop("Integration bounds not given.")
  # and delete them from the call
  av[[paste(wrt,".from",sep="")]] <- NULL
  av[[paste(wrt,".to",sep="")]] <- NULL
  newf <- function(vi){
    av[[wrt]] = vi
    do.call(f,av,quote=TRUE) + 0*vi #make the same size as vi
  }
  # NEED TO ADD TOLERANCE
  # Copy code from old antiD
  # But first test it out for scalar inputs.
  integrate(newf, vi.from, vi.to )$value
}