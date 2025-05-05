# NeoRack - Taking Ruby's Rack into the Future

NeoRack, like [Rack](https://github.com/rack/rack), provides [a specification](./SPEC.md) detailing how Ruby Servers and Web Applications interact.

Where Rack is based on the historical CGI specification, NeoRack looks to the future and aims to provide solutions for modern Web Applications.

## Backwards compatibility?

> "[All for the sake of momentum,](https://youtu.be/2F-0pKS3xgk?t=105)
> 
>  [I'm condemning the future to death,](https://youtu.be/2F-0pKS3xgk?t=105)
>  
>  [so it can match the past.](https://youtu.be/2F-0pKS3xgk?t=105)"
>  
>  - Aimee Mann

NeoRack applications are designed in a way that allows NeoRack to "host" or contain one or more Rack applications - this way, backwards compatibility can be achieved.

However, the Rack specification simply has too many limitations and it's making it hard for Ruby Web Applications to leverage modern web technologies and features.

Much has been written about this, [issues were already glaring at us more than 12 years ago](http://blog.plataformatec.com.br/2012/06/why-your-web-framework-should-not-adopt-rack-api/)... but backwards compatibility is alluring and momentum has its way.

Perhaps the existing Rack design will prove to be better and NeoRack will fade away, much like [Rack-Next](https://github.com/Wardrop/Rack-Next), [The Metal](https://github.com/tenderlove/the_metal), and others. Maybe NeoRack will prove better, but still momentum will win.

But if we don't allow ourselves a clean slate and a fresh start - how would we ever know?

> [It's the question that drives us, Neo.](https://youtu.be/jXeF1rMkpQw?t=80)
> 
>  - The Matrix

What if we took more than a decade of experience and wrote a specification designed for modern Web Applications?

Yes, new code wouldn't be able to use old code without accepting old limitations, or without porting it to the new specification - but what about new code? what would we be able to accomplish with if we implemented all the lessons we learned in the past?
